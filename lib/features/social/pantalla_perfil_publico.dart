import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../profile/cabecera_perfil.dart';
import '../profile/calendario_social.dart';
import '../profile/pestanas_perfil.dart';

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
/// falta antes de quedar con un desconocido. Por eso la foto, sus redes y
/// cuando sale van antes que cualquier boton.
class PantallaPerfilPublico extends ConsumerWidget {
  const PantallaPerfilPublico({super.key, required this.perfilId});

  final String perfilId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(_perfilProvider(perfilId));

    return Scaffold(
      body: perfil.when(
        loading: () => const Stack(children: [Cargando(), _Volver()]),
        error: (e, _) => Stack(
          children: [
            EstadoVacio(
              icono: Icons.person_off_outlined,
              titulo: 'No disponible',
              detalle: 'Este perfil no existe o no se puede ver ahora.',
              accion: 'Reintentar',
              onAccion: () => ref.invalidate(_perfilProvider(perfilId)),
            ),
            const _Volver(),
          ],
        ),
        data: (ficha) => _Contenido(ficha: ficha),
      ),
    );
  }
}

class _Volver extends StatelessWidget {
  const _Volver();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      child: BotonCristal(
        icono: Icons.arrow_back_rounded,
        etiqueta: 'Volver',
        onTap: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

class _Contenido extends ConsumerStatefulWidget {
  const _Contenido({required this.ficha});

  final PerfilPublico ficha;

  @override
  ConsumerState<_Contenido> createState() => _ContenidoState();
}

class _ContenidoState extends ConsumerState<_Contenido> {
  late PerfilResumen _p = widget.ficha.perfil;

  /// Lo que se ha movido el contador de seguidores sin esperar al servidor.
  int _ajusteSeguidores = 0;

  /// Dos toques rapidos lanzarian seguir y dejar de seguir a la vez, y el
  /// orden en que lleguen al servidor decide el resultado, no el usuario.
  bool _enCurso = false;

  @override
  void didUpdateWidget(covariant _Contenido anterior) {
    super.didUpdateWidget(anterior);
    // Si la ficha se recarga, manda la del servidor y no la copia local.
    if (anterior.ficha != widget.ficha) {
      _p = widget.ficha.perfil;
      _ajusteSeguidores = 0;
    }
  }

  Future<void> _alternar() async {
    if (_enCurso) return;
    HapticFeedback.selectionClick();
    final antes = _p;
    final ajusteAntes = _ajusteSeguidores;
    setState(() {
      _enCurso = true;
      _p = _p.copiarCon(leSigo: !antes.leSigo);
      _ajusteSeguidores += antes.leSigo ? -1 : 1;
    });
    try {
      await ref
          .read(repositorioSocialProvider)
          .alternarSeguimiento(antes.id, loSeguia: antes.leSigo);
    } catch (_) {
      if (mounted) {
        setState(() {
          _p = antes;
          _ajusteSeguidores = ajusteAntes;
        });
      }
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ficha = widget.ficha;
    final publicaciones = ref.watch(_publicacionesProvider(_p.id));
    // A uno mismo no se le sigue ni se le escribe: se llega aqui desde el
    // feed o el buscador tocando tu propia cara.
    final esMio = ref.watch(uidActualProvider) == _p.id;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CabeceraDePerfil(
            ficha: FichaDeCabecera(
              nombre: _p.nombre,
              usuario: _p.usuario,
              avatar: _p.avatar,
              bio: ficha.bio,
              ciudad: ficha.ciudad,
              reputacion: _p.reputacion,
              instagram: ficha.instagram,
              tiktok: ficha.tiktok,
              xUsuario: ficha.xUsuario,
              seguidores: ficha.seguidores + _ajusteSeguidores,
              siguiendo: ficha.siguiendo,
              publicaciones: publicaciones.valueOrNull?.length,
            ),
            encima: const _Volver(),
            acciones: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ficha.esDemo) ...[
                  const _AvisoDemo(),
                  const SizedBox(height: EspaciadoPrevia.m),
                ],
                if (!esMio)
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: MovimientoPrevia.rapido,
                          child: _p.leSigo
                              ? OutlinedButton.icon(
                                  key: const ValueKey('sigo'),
                                  onPressed: _alternar,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 19,
                                  ),
                                  label: const Text('Siguiendo'),
                                )
                              : FilledButton(
                                  key: const ValueKey('seguir'),
                                  onPressed: _alternar,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(46),
                                  ),
                                  child: const Text('SEGUIR'),
                                ),
                        ),
                      ),
                      const SizedBox(width: EspaciadoPrevia.s),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('${Rutas.conversacion}/${_p.id}'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Mensaje'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.xl,
            EspaciadoPrevia.m,
            EspaciadoPrevia.l,
          ),
          sliver: SliverToBoxAdapter(
            child: CalendarioSocial(perfilId: _p.id, esMio: esMio),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.s,
            EspaciadoPrevia.m,
            EspaciadoPrevia.m,
          ),
          sliver: SliverToBoxAdapter(child: Titular('Fotos', tamano: 24)),
        ),
        SliverRejillaDeFotos(
          publicaciones: publicaciones,
          vacio: const EstadoVacio(
            compacto: true,
            pegatina: '🌙',
            titulo: 'Sin fotos todavía',
            detalle: 'Cuando suba algo de sus noches aparecerá aquí.',
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: context.holguraInferior + EspaciadoPrevia.l),
        ),
      ],
    );
  }
}

class _AvisoDemo extends StatelessWidget {
  const _AvisoDemo();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(EspaciadoPrevia.s + EspaciadoPrevia.xs),
    decoration: BoxDecoration(
      color: context.colores.superficieAlta,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio - 4),
    ),
    child: Row(
      children: [
        Icon(
          Icons.science_outlined,
          size: 18,
          color: context.colores.textoTenue,
        ),
        const SizedBox(width: EspaciadoPrevia.s),
        Expanded(
          child: Text(
            'Perfil de ejemplo. No es una persona real.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
