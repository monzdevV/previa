import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_social.dart';

/// Subir una foto o un video de la noche.
class PantallaPublicar extends ConsumerStatefulWidget {
  const PantallaPublicar({super.key});

  @override
  ConsumerState<PantallaPublicar> createState() => _PantallaPublicarState();
}

class _PantallaPublicarState extends ConsumerState<PantallaPublicar> {
  final _texto = TextEditingController();
  final _zona = TextEditingController();

  XFile? _media;
  List<int>? _bytes;
  bool _esVideo = false;
  bool _subiendo = false;
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    _zona.dispose();
    super.dispose();
  }

  Future<void> _elegir({required bool video, required bool camara}) async {
    final selector = ImagePicker();
    final origen = camara ? ImageSource.camera : ImageSource.gallery;

    final fichero = video
        ? await selector.pickVideo(
            source: origen,
            // Un minuto es de sobra para un clip de fiesta y evita subidas
            // de cientos de megas desde el movil.
            maxDuration: const Duration(minutes: 1),
          )
        : await selector.pickImage(
            source: origen,
            maxWidth: 1600,
            imageQuality: 82,
          );

    if (fichero == null) return;
    final bytes = await fichero.readAsBytes();

    if (!mounted) return;
    setState(() {
      _media = fichero;
      _bytes = bytes;
      _esVideo = video;
      _error = null;
    });
  }

  Future<void> _publicar() async {
    final bytes = _bytes;
    final media = _media;
    if (bytes == null || media == null) return;

    setState(() {
      _subiendo = true;
      _error = null;
    });

    try {
      final punto = media.name.lastIndexOf('.');
      final extension = punto > 0
          ? media.name.substring(punto + 1).toLowerCase()
          : (_esVideo ? 'mp4' : 'jpg');

      await ref
          .read(repositorioSocialProvider)
          .publicar(
            bytes: bytes,
            extension: extension,
            esVideo: _esVideo,
            texto: _texto.text,
            zona: _zona.text,
          );

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se ha podido subir. Inténtalo otra vez.');
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayMedia = _media != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva publicación'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        children: [
          _Lienzo(media: _media, esVideo: _esVideo),

          const SizedBox(height: EspaciadoPrevia.m),

          Row(
            children: [
              Expanded(
                child: _BotonOrigen(
                  icono: Icons.photo_camera_rounded,
                  texto: 'Cámara',
                  onTap: _subiendo
                      ? null
                      : () => _elegir(video: false, camara: true),
                ),
              ),
              const SizedBox(width: EspaciadoPrevia.s),
              Expanded(
                child: _BotonOrigen(
                  icono: Icons.photo_library_rounded,
                  texto: 'Galería',
                  onTap: _subiendo
                      ? null
                      : () => _elegir(video: false, camara: false),
                ),
              ),
              const SizedBox(width: EspaciadoPrevia.s),
              Expanded(
                child: _BotonOrigen(
                  icono: Icons.videocam_rounded,
                  texto: 'Vídeo',
                  onTap: _subiendo
                      ? null
                      : () => _elegir(video: true, camara: false),
                ),
              ),
            ],
          ),

          const SizedBox(height: EspaciadoPrevia.l),

          TextField(
            controller: _texto,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: '¿Qué está pasando?',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: _zona,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Zona',
              hintText: 'Zaragoza, Centro, Malasaña…',
              helperText: 'Es lo que permite a otros ver la noche de su ciudad.',
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              _error!,
              style: const TextStyle(color: ColoresPrevia.error),
            ),
          ],

          const SizedBox(height: EspaciadoPrevia.l),
          FilledButton(
            onPressed: hayMedia && !_subiendo ? _publicar : null,
            child: _subiendo
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: ColoresPrevia.sobrePrimario,
                    ),
                  )
                : const Text('Publicar'),
          ),
        ],
      ),
    );
  }
}

class _Lienzo extends StatelessWidget {
  const _Lienzo({required this.media, required this.esVideo});

  final XFile? media;
  final bool esVideo;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ColoresPrevia.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
        ),
        child: media == null
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: ColoresPrevia.textoTenue,
                    ),
                    SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      'Elige una foto o un vídeo',
                      style: TextStyle(color: ColoresPrevia.textoTenue),
                    ),
                  ],
                ),
              )
            : esVideo
            // El video no se previsualiza aqui: cargar un reproductor solo
            // para confirmar que has elegido el fichero correcto es caro.
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.movie_rounded,
                      size: 40,
                      color: ColoresPrevia.primario,
                    ),
                    const SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      media!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresPrevia.textoSuave),
                    ),
                  ],
                ),
              )
            : Image.network(media!.path, fit: BoxFit.cover),
      ),
    );
  }
}

class _BotonOrigen extends StatelessWidget {
  const _BotonOrigen({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ColoresPrevia.superficieAlta,
    borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EspaciadoPrevia.m),
        child: Column(
          children: [
            Icon(icono, color: ColoresPrevia.texto),
            const SizedBox(height: EspaciadoPrevia.xs + 2),
            Text(
              texto,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}
