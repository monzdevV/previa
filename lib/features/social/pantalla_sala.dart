import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

final _mensajesProvider = FutureProvider.family<List<MensajeDeSala>, String>(
  (ref, localId) => ref.watch(repositorioSocialProvider).salaMensajes(localId),
);

final _fotosProvider = FutureProvider.family<List<Publicacion>, String>(
  (ref, localId) => ref.watch(repositorioSocialProvider).salaFotos(localId),
);

/// La sala de un local durante la noche.
///
/// Solo entra quien ha dicho que va, y eso se comprueba en la base de datos.
/// Si cualquiera pudiera escribir desde su casa, estar dentro dejaria de
/// significar nada, que es justo lo que hace que la sala tenga gracia.
class PantallaSala extends ConsumerStatefulWidget {
  const PantallaSala({
    super.key,
    required this.localId,
    required this.nombreLocal,
  });

  final String localId;
  final String nombreLocal;

  @override
  ConsumerState<PantallaSala> createState() => _PantallaSalaState();
}

class _PantallaSalaState extends ConsumerState<PantallaSala> {
  @override
  void initState() {
    super.initState();
    // Refresca al vuelo cuando alguien escribe en la sala.
    ref
        .read(repositorioSocialProvider)
        .flujoDeSala(widget.localId)
        .listen((_) {
          if (mounted) ref.invalidate(_mensajesProvider(widget.localId));
        });
  }

  @override
  Widget build(BuildContext context) {
    final esta = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(DateTime.now());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.nombreLocal),
              Text(
                esta,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.colores.textoTenue,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: context.colores.primario,
            labelColor: context.colores.texto,
            unselectedLabelColor: context.colores.textoTenue,
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Fotos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Chat(localId: widget.localId),
            _Fotos(localId: widget.localId),
          ],
        ),
      ),
    );
  }
}

class _Chat extends ConsumerStatefulWidget {
  const _Chat({required this.localId});

  final String localId;

  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  final _campo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _campo.text;
    if (texto.trim().isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _campo.clear();
    try {
      await ref
          .read(repositorioSocialProvider)
          .escribirEnSala(widget.localId, texto);
      ref.invalidate(_mensajesProvider(widget.localId));
    } catch (e) {
      if (mounted) {
        _campo.text = texto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para escribir aquí tienes que decir primero que vas.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(_mensajesProvider(widget.localId));

    return Column(
      children: [
        Expanded(
          child: mensajes.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: context.colores.primarioTexto),
            ),
            error: (e, _) => const _Cerrada(),
            data: (lista) => lista.isEmpty
                ? const _Mensaje(
                    texto: 'La sala está vacía.\nDi algo y que se anime.',
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(EspaciadoPrevia.m),
                    itemCount: lista.length,
                    itemBuilder: (_, i) =>
                        _Burbuja(mensaje: lista[lista.length - 1 - i]),
                  ),
          ),
        ),

        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(EspaciadoPrevia.s + EspaciadoPrevia.xs),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campo,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Escribe en la sala',
                    ),
                    onSubmitted: (_) => _enviar(),
                  ),
                ),
                const SizedBox(width: EspaciadoPrevia.s),
                IconButton.filled(
                  onPressed: _enviando ? null : _enviar,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: context.colores.primario,
                    foregroundColor: context.colores.sobrePrimario,
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeDeSala mensaje;

  @override
  Widget build(BuildContext context) {
    final mio = mensaje.mio;

    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
      child: Row(
        mainAxisAlignment: mio
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mio) ...[
            AvatarPerfil(
              url: mensaje.autorAvatar,
              inicial: mensaje.autorNombre,
              lado: 28,
            ),
            const SizedBox(width: EspaciadoPrevia.s),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: EspaciadoPrevia.m,
                vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
              ),
              decoration: BoxDecoration(
                color: mio
                    ? context.colores.primario
                    : context.colores.superficieAlta,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mio)
                    Text(
                      mensaje.autorNombre,
                      style: TextStyle(
                        color: context.colores.primarioTexto,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    mensaje.texto,
                    style: TextStyle(
                      color: mio
                          ? context.colores.sobrePrimario
                          : context.colores.texto,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fotos extends ConsumerWidget {
  const _Fotos({required this.localId});

  final String localId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(_fotosProvider(localId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: fotos.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colores.primarioTexto),
        ),
        error: (e, _) => const _Cerrada(),
        data: (lista) => lista.isEmpty
            ? const _Mensaje(
                texto: 'Todavía no hay fotos de esta noche.\n'
                    'Sube la primera.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(3),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                itemCount: lista.length,
                itemBuilder: (_, i) => CachedNetworkImage(
                  imageUrl: lista[i].mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      ColoredBox(color: context.colores.superficie),
                  errorWidget: (_, _, _) =>
                      ColoredBox(color: context.colores.superficie),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _subir(context, ref, localId),
        child: const Icon(Icons.add_a_photo_rounded),
      ),
    );
  }
}

Future<void> _subir(BuildContext context, WidgetRef ref, String localId) async {
  final elegida = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 82,
  );
  if (elegida == null) return;

  final bytes = await elegida.readAsBytes();
  final punto = elegida.name.lastIndexOf('.');

  try {
    await ref
        .read(repositorioSocialProvider)
        .publicarEnSala(
          localId: localId,
          bytes: bytes,
          extension: punto > 0
              ? elegida.name.substring(punto + 1).toLowerCase()
              : 'jpg',
          esVideo: false,
        );
    ref.invalidate(_fotosProvider(localId));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido subir.')),
      );
    }
  }
}

/// Lo que ve quien no ha dicho que va.
class _Cerrada extends StatelessWidget {
  const _Cerrada();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 40,
            color: context.colores.textoTenue,
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          Text(
            'La sala es para quien está',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          Text(
            'Di que vas a este sitio y entrarás al chat y a las fotos '
            'de esta noche.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
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
