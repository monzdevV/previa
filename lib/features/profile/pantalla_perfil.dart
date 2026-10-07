import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../map/proveedores_mapa.dart';
import '../party/tarjeta_previa.dart';
import '../social/pantalla_resumen_noche.dart' show InsigniaDeRacha;
import 'cabecera_perfil.dart';
import 'calendario_social.dart';
import 'pestanas_perfil.dart';
import 'proveedores_perfil.dart';
import 'reputacion.dart';

/// Tu perfil, como lo ven los demas, con lo tuyo encima.
///
/// Antes era una lista de catorce entradas (solicitudes, valorar, datos,
/// borrar la cuenta...) debajo de la foto. Todo eso se usa una vez al mes y
/// vive ahora en Ajustes, detras del unico boton de arriba. Aqui queda lo que
/// se viene a mirar: tu cara, tus redes y tus noches.
class PantallaPerfil extends ConsumerStatefulWidget {
  const PantallaPerfil({super.key});

  @override
  ConsumerState<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends ConsumerState<PantallaPerfil> {
  /// 0: tus fotos, 1: las de esas noches.
  int _seccion = 0;

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(miPerfilProvider);

    return Scaffold(
      body: perfil.when(
        loading: () => const Cargando(),
        error: (e, _) => EstadoVacio(
          icono: Icons.cloud_off_rounded,
          titulo: 'Sin conexión',
          detalle: 'No hemos podido cargar tu perfil.',
          accion: 'Reintentar',
          onAccion: () => refrescarPerfil(ref),
        ),
        data: (p) {
          if (p == null) return const SizedBox.shrink();
          final ficha = ref.watch(miFichaProvider(p.id)).valueOrNull;
          final mias = ref.watch(misPublicacionesProvider);
          final misPrevias = ref.watch(misPreviasProvider).valueOrNull ?? [];
          void editar() => context.push(Rutas.editarPerfil);

          return RefreshIndicator(
            color: context.colores.primarioTexto,
            backgroundColor: context.colores.superficie,
            // Se espera a que vuelvan los datos: si no, la ruleta se va al
            // instante y parece que no ha hecho nada.
            onRefresh: () async {
              refrescarPerfil(ref);
              ref.invalidate(misPreviasProvider);
              try {
                await ref.read(miPerfilProvider.future);
              } catch (_) {
                // El fallo ya lo pinta la propia pantalla.
              }
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: CabeceraDePerfil(
                    ficha: FichaDeCabecera(
                      nombre: p.nombre,
                      usuario: p.username,
                      avatar: p.avatarUrl,
                      bio: p.bio,
                      ciudad: p.ciudad,
                      // La nota va en su bloque justo debajo, con las
                      // insignias: repetirla aqui solo meteria ruido.
                      instagram: p.instagram,
                      tiktok: p.tiktok,
                      xUsuario: p.xUsuario,
                      seguidores: ficha?.seguidores,
                      siguiendo: ficha?.siguiendo,
                      publicaciones: mias.valueOrNull?.length,
                    ),
                    insignia: const InsigniaDeRacha(),
                    onAnadirFoto: editar,
                    onAnadirRedes: editar,
                    encima: SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(EspaciadoPrevia.m),
                          child: BotonCristal(
                            icono: Icons.settings_rounded,
                            etiqueta: 'Ajustes',
                            onTap: () => context.push(Rutas.ajustes),
                          ),
                        ),
                      ),
                    ),
                    acciones: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: editar,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Editar perfil'),
                          ),
                        ),
                        const SizedBox(width: EspaciadoPrevia.s),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push(Rutas.buscar),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Añadir gente'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    EspaciadoPrevia.m,
                    EspaciadoPrevia.l,
                    EspaciadoPrevia.m,
                    0,
                  ),
                  sliver: SliverList.list(
                    children: [
                      TarjetaReputacion(perfil: p),
                      const SizedBox(height: EspaciadoPrevia.m),
                      TarjetaCompletarPerfil(
                        faltaFoto: p.avatarUrl == null || p.avatarUrl!.isEmpty,
                        faltanRedes: !p.tieneRedes,
                        faltaBio: p.bio == null || p.bio!.trim().isEmpty,
                        onTap: editar,
                      ),
                      if (p.avatarUrl == null ||
                          !p.tieneRedes ||
                          (p.bio ?? '').trim().isEmpty)
                        const SizedBox(height: EspaciadoPrevia.l),
                      CalendarioSocial(perfilId: p.id, esMio: true),
                      if (misPrevias.isNotEmpty) ...[
                        const SizedBox(height: EspaciadoPrevia.xl),
                        const Titular('Tus previas', tamano: 24),
                        const SizedBox(height: EspaciadoPrevia.m),
                        for (final previa in misPrevias)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: EspaciadoPrevia.s,
                            ),
                            child: TarjetaPrevia(
                              previa: previa,
                              compacta: true,
                              onTap: () =>
                                  context.push('${Rutas.previa}/${previa.id}'),
                            ),
                          ),
                      ],
                      const SizedBox(height: EspaciadoPrevia.xl),
                      Conmutador(
                        opciones: const ['Tus fotos', 'De esas noches'],
                        elegida: _seccion,
                        onElegir: (i) => setState(() => _seccion = i),
                      ),
                      const SizedBox(height: EspaciadoPrevia.m),
                    ],
                  ),
                ),
                if (_seccion == 0)
                  SliverRejillaDeFotos(
                    publicaciones: mias,
                    borrables: true,
                    vacio: const EstadoVacio(
                      compacto: true,
                      pegatina: '📷',
                      titulo: 'Tu primera foto',
                      detalle:
                          'Sube algo de la última noche con el + de Inicio. '
                          'Mantén pulsada una foto para borrarla.',
                    ),
                  )
                else
                  const SliverDeEsasNoches(),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: context.holguraInferior + EspaciadoPrevia.l,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
