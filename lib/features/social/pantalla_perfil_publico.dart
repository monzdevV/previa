import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

final _perfilProvider = FutureProvider.family<PerfilPublico, String>(
  (ref, id) => ref.watch(repositorioSocialProvider).perfilPublico(id),
);

final _publicacionesProvider = FutureProvider.family<List<Publicacion>, String>(
  (ref, id) => ref.watch(repositorioSocialProvider).publicacionesDe(id),
);

/// El perfil de otra persona.
///
/// Es la pantalla que cierra el circulo social: sin ella se puede seguir a
/// alguien pero no saber quien es, que es justo lo contrario de lo que hace
/// falta antes de quedar con un desconocido.
class PantallaPerfilPublico extends ConsumerWidget {
  const PantallaPerfilPublico({super.key, required this.perfilId});

  final String perfilId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(_perfilProvider(perfilId));

    return Scaffold(
      appBar: AppBar(title: Text(perfil.valueOrNull?.perfil.nombre ?? 'Perfil')),
      body: perfil.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ColoresPrevia.primario),
        ),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(EspaciadoPrevia.xl),
            child: Text('No se ha podido cargar este perfil.'),
          ),
        ),
        data: (ficha) => _Contenido(ficha: ficha),
      ),
    );
  }
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.ficha});

  final PerfilPublico ficha;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  late PerfilResumen _p = widget.ficha.perfil;

  Future<void> _alternar() async {
    final antes = _p;
    setState(() => _p = _p.copiarCon(leSigo: !antes.leSigo));
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarSeguimiento(antes.id, loSeguia: antes.leSigo);
    } catch (_) {
      if (mounted) setState(() => _p = antes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final textos = Theme.of(context).textTheme;
    final publicaciones = ref.watch(_publicacionesProvider(_p.id));

    return ListView(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      children: [
        Row(
          children: [
            AvatarPerfil(url: _p.avatar, inicial: _p.nombre, lado: 86),
            const SizedBox(width: EspaciadoPrevia.m),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Contador(
                    valor: publicaciones.valueOrNull?.length ?? 0,
                    etiqueta: 'noches',
                  ),
                  _Contador(
                    valor: ficha.seguidores,
                    etiqueta: 'seguidores',
                  ),
                  _Contador(valor: ficha.siguiendo, etiqueta: 'siguiendo'),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: EspaciadoPrevia.m),
        Text(_p.nombre, style: textos.titleLarge),
        if (_p.usuario != null)
          Text('@${_p.usuario}', style: textos.bodyMedium),

        if (ficha.bio != null && ficha.bio!.isNotEmpty) ...[
          const SizedBox(height: EspaciadoPrevia.s),
          Text(ficha.bio!, style: textos.bodyLarge),
        ],

        const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
        Wrap(
          spacing: EspaciadoPrevia.s,
          runSpacing: EspaciadoPrevia.xs + 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (ficha.ciudad != null) _Dato(Icons.place_outlined, ficha.ciudad!),
            if (_p.reputacion != null)
              _Dato(
                Icons.star_rounded,
                '${_p.reputacion!.toStringAsFixed(1).replaceAll('.', ',')} de 5',
              ),
            if (ficha.instagram != null)
              ActionChip(
                avatar: const Icon(Icons.alternate_email_rounded, size: 16),
                label: Text(ficha.instagram!),
                onPressed: () => _abrirInstagram(ficha.instagram!),
              ),
          ],
        ),

        if (ficha.esDemo) ...[
          const SizedBox(height: EspaciadoPrevia.m),
          const _AvisoDemo(),
        ],

        const SizedBox(height: EspaciadoPrevia.m),
        _p.leSigo
            ? OutlinedButton.icon(
                onPressed: _alternar,
                icon: const Icon(Icons.check_rounded, size: 19),
                label: const Text('Siguiendo'),
              )
            : FilledButton(onPressed: _alternar, child: const Text('Seguir')),

        const SizedBox(height: EspaciadoPrevia.l),
        const Divider(),
        const SizedBox(height: EspaciadoPrevia.m),

        publicaciones.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(EspaciadoPrevia.xl),
              child: CircularProgressIndicator(color: ColoresPrevia.primario),
            ),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (lista) => lista.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: EspaciadoPrevia.xl,
                  ),
                  child: Text(
                    'Todavía no ha publicado nada.',
                    textAlign: TextAlign.center,
                    style: textos.bodyMedium,
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                      ),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _Miniatura(publicacion: lista[i]),
                ),
        ),
      ],
    );
  }
}

Future<void> _abrirInstagram(String usuario) async {
  final destino = Uri.parse('https://instagram.com/$usuario');
  await launchUrl(destino, mode: LaunchMode.externalApplication);
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.publicacion});

  final Publicacion publicacion;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CachedNetworkImage(
        imageUrl: publicacion.miniaturaUrl ?? publicacion.mediaUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) =>
            const ColoredBox(color: ColoresPrevia.superficie),
        errorWidget: (_, _, _) =>
            const ColoredBox(color: ColoresPrevia.superficie),
      ),
      if (publicacion.esVideo)
        const Positioned(
          top: 4,
          right: 4,
          child: Icon(
            Icons.play_circle_fill_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
    ],
  );
}

class _Contador extends StatelessWidget {
  const _Contador({required this.valor, required this.etiqueta});

  final int valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$valor',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      Text(etiqueta, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 16, color: ColoresPrevia.textoTenue),
      const SizedBox(width: EspaciadoPrevia.xs),
      Text(texto, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _AvisoDemo extends StatelessWidget {
  const _AvisoDemo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(EspaciadoPrevia.s + EspaciadoPrevia.xs),
    decoration: BoxDecoration(
      color: ColoresPrevia.superficieAlta,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.science_outlined,
          size: 18,
          color: ColoresPrevia.textoTenue,
        ),
        const SizedBox(width: EspaciadoPrevia.s),
        Expanded(
          child: Text(
            'Perfil de ejemplo. No es una persona real.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
