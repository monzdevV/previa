import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';
import '../feed/pantalla_feed.dart' show AvatarPerfil;

final avisosProvider = FutureProvider<List<Aviso>>(
  (ref) => ref.watch(repositorioSocialProvider).misAvisos(),
);

/// Cuantos avisos sin leer hay. Se escucha en vivo para que la chincheta
/// suba sin recargar.
final sinLeerProvider = StreamProvider<int>(
  (ref) => ref.watch(repositorioSocialProvider).flujoDeAvisos(),
);

/// Los avisos.
///
/// Sin esto alguien te pide plaza o te escribe y no te enteras hasta que
/// abres la pantalla concreta, que es lo que hace que una aplicacion social
/// se pruebe una vez y no se vuelva a abrir.
class PantallaAvisos extends ConsumerStatefulWidget {
  const PantallaAvisos({super.key});

  @override
  ConsumerState<PantallaAvisos> createState() => _PantallaAvisosState();
}

class _PantallaAvisosState extends ConsumerState<PantallaAvisos> {
  @override
  void initState() {
    super.initState();
    // Se marcan al abrir, no al cerrar: si no, la chincheta sigue en rojo
    // mientras los estas leyendo.
    ref.read(repositorioSocialProvider).marcarAvisosLeidos();
  }

  @override
  Widget build(BuildContext context) {
    final avisos = ref.watch(avisosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: avisos.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colores.primarioTexto),
        ),
        error: (e, _) => const _Mensaje(texto: 'No se ha podido cargar.'),
        data: (lista) => lista.isEmpty
            ? const _Mensaje(
                texto: 'Nada nuevo.\nAquí verás quién te pide plaza, '
                    'quién te escribe y quién te sigue.',
              )
            : RefreshIndicator(
                color: context.colores.primarioTexto,
                backgroundColor: context.colores.superficie,
                onRefresh: () async => ref.refresh(avisosProvider.future),
                child: ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (_, i) => _Fila(aviso: lista[i]),
                ),
              ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.aviso});

  final Aviso aviso;

  /// A donde lleva cada tipo de aviso.
  void _abrir(BuildContext context) {
    final a = aviso;
    if (a.tipo == 'mensaje' && a.actorId != null) {
      context.push('${Rutas.conversacion}/${a.actorId}');
    } else if (a.previaId != null) {
      context.push('${Rutas.previa}/${a.previaId}');
    } else if (a.actorId != null) {
      context.push('${Rutas.perfilDe}/${a.actorId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = aviso;
    final textos = Theme.of(context).textTheme;

    return ListTile(
      onTap: () => _abrir(context),
      tileColor: a.leido ? null : context.colores.superficie,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.xs,
      ),
      leading: AvatarPerfil(
        url: a.actorAvatar,
        inicial: a.quien,
        lado: 46,
      ),
      title: Text(a.texto, style: textos.bodyLarge),
      subtitle: Text(
        DateFormat('d MMM · HH:mm', 'es_ES').format(a.creadoEn),
        style: textos.labelMedium,
      ),
      trailing: Icon(_icono(a.tipo), size: 20, color: _tinta(context, a.tipo)),
    );
  }

  IconData _icono(String tipo) => switch (tipo) {
    'solicitud' => Icons.pan_tool_alt_outlined,
    'aceptada' => Icons.check_circle_outline_rounded,
    'mensaje' => Icons.chat_bubble_outline_rounded,
    'like' => Icons.favorite_border_rounded,
    'seguidor' => Icons.person_add_alt_1_outlined,
    _ => Icons.forum_outlined,
  };

  Color _tinta(BuildContext context, String tipo) => switch (tipo) {
    'aceptada' => context.colores.disponible,
    'like' => context.colores.primarioTexto,
    _ => context.colores.textoTenue,
  };
}

/// La chincheta con los avisos sin leer, para la barra del feed.
class ChinchetaDeAvisos extends ConsumerWidget {
  const ChinchetaDeAvisos({super.key, required this.hijo});

  final Widget hijo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinLeer = ref.watch(sinLeerProvider).valueOrNull ?? 0;
    if (sinLeer == 0) return hijo;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        hijo,
        Positioned(
          top: -2,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colores.error,
              borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
            ),
            child: Text(
              sinLeer > 9 ? '9+' : '$sinLeer',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
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
