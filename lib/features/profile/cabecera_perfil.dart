import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/tema.dart';
import 'redes_sociales.dart';

/// Lo que ensena la cabecera, venga del perfil propio o del de otro.
class FichaDeCabecera {
  const FichaDeCabecera({
    required this.nombre,
    this.usuario,
    this.avatar,
    this.bio,
    this.ciudad,
    this.reputacion,
    this.instagram,
    this.tiktok,
    this.xUsuario,
    this.seguidores,
    this.siguiendo,
    this.publicaciones,
  });

  final String nombre;
  final String? usuario;
  final String? avatar;
  final String? bio;
  final String? ciudad;
  /// Nula si nadie le ha valorado todavia: un 0 seria mentira.
  final double? reputacion;
  final String? instagram;
  final String? tiktok;
  final String? xUsuario;

  /// Nulos mientras cargan: se pinta un guion y no un cero que salte.
  final int? seguidores;
  final int? siguiendo;
  final int? publicaciones;

  bool get tieneFoto => avatar != null && avatar!.isNotEmpty;
}

/// La cabecera de un perfil, el tuyo o el de otra persona.
///
/// La foto va a sangre y manda: es lo que se mira antes de quedar con
/// alguien, y en BeReal o Instagram es lo primero que se ve. El nombre va
/// encima en la letra gorda, sobre un velo, como en los carteles de local.
///
/// Sin foto no queda un hueco gris: el bloque de color de esa persona con su
/// inicial enorme, y si el perfil es tuyo, la invitacion a ponerla.
class CabeceraDePerfil extends StatelessWidget {
  const CabeceraDePerfil({
    super.key,
    required this.ficha,
    required this.acciones,
    this.insignia,
    this.encima,
    this.onAnadirFoto,
    this.onAnadirRedes,
  });

  final FichaDeCabecera ficha;

  /// Los botones bajo la cabecera: editar, o seguir y escribir.
  final Widget acciones;

  /// Algo pequeño junto a los contadores, como la racha.
  final Widget? insignia;

  /// Controles que flotan sobre la foto (volver, ajustes).
  final Widget? encima;

  final VoidCallback? onAnadirFoto;
  final VoidCallback? onAnadirRedes;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final textos = Theme.of(context).textTheme;
    final tamano = MediaQuery.sizeOf(context);
    // Cuadrada, pero sin comerse mas de la mitad de la pantalla: en un
    // movil bajo el calendario tiene que asomar sin hacer scroll.
    final altoFoto = (tamano.width).clamp(0.0, tamano.height * 0.52);

    final datos = <String>[
      if (ficha.ciudad != null && ficha.ciudad!.isNotEmpty) ficha.ciudad!,
      if (ficha.reputacion != null)
        '★ ${ficha.reputacion!.toStringAsFixed(1).replaceAll('.', ',')}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: altoFoto,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Foto(ficha: ficha, onAnadirFoto: onAnadirFoto),
              // Velo hacia el fondo de la app: la foto se funde con la
              // pagina en vez de acabar en un corte.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.22, 0.55, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.transparent,
                      c.fondo,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: EspaciadoPrevia.m,
                right: EspaciadoPrevia.m,
                bottom: EspaciadoPrevia.s,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Titular(ficha.nombre, tamano: 46, lineas: 2),
                    ),
                    if (ficha.usuario != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          '@${ficha.usuario}',
                          ...datos,
                        ].join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textoSuave,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?encima,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.s,
            EspaciadoPrevia.m,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Cifra(valor: ficha.publicaciones, etiqueta: 'fotos'),
                  _Cifra(valor: ficha.seguidores, etiqueta: 'seguidores'),
                  _Cifra(valor: ficha.siguiendo, etiqueta: 'siguiendo'),
                  const Spacer(),
                  ?insignia,
                ],
              ),
              if (ficha.bio != null && ficha.bio!.isNotEmpty) ...[
                const SizedBox(height: EspaciadoPrevia.m),
                Text(ficha.bio!, style: textos.bodyLarge),
              ],
              const SizedBox(height: EspaciadoPrevia.m),
              FilaDeRedes(
                instagram: ficha.instagram,
                tiktok: ficha.tiktok,
                xUsuario: ficha.xUsuario,
                onAnadir: onAnadirRedes,
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              acciones,
            ],
          ),
        ),
      ],
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({required this.ficha, this.onAnadirFoto});

  final FichaDeCabecera ficha;
  final VoidCallback? onAnadirFoto;

  @override
  Widget build(BuildContext context) {
    if (ficha.tieneFoto) {
      return CachedNetworkImage(
        imageUrl: ficha.avatar!,
        fit: BoxFit.cover,
        fadeInDuration: MovimientoPrevia.normal,
        placeholder: (_, _) =>
            ColoredBox(color: context.colores.superficieAlta),
        errorWidget: (_, _, _) => _SinFoto(ficha: ficha),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _SinFoto(ficha: ficha),
        if (onAnadirFoto != null)
          Align(
            alignment: const Alignment(0, -0.1),
            child: Pulsable(
              onTap: onAnadirFoto,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: BloquesPrevia.tintaSobreBloque,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    SizedBox(width: EspaciadoPrevia.s),
                    Text(
                      'AÑADE TU FOTO',
                      style: TextStyle(
                        fontFamily: LetraPrevia.titular,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto({required this.ficha});

  final FichaDeCabecera ficha;

  @override
  Widget build(BuildContext context) {
    final letra = ficha.nombre.trim().isEmpty
        ? '?'
        : ficha.nombre.trim()[0].toUpperCase();
    return ColoredBox(
      color: BloquesPrevia.deIndice(ficha.nombre.hashCode.abs()),
      child: ClipRect(
        child: Align(
          alignment: const Alignment(0.9, -0.2),
          child: Text(
            letra,
            style: TextStyle(
              fontFamily: LetraPrevia.titular,
              fontWeight: FontWeight.w900,
              fontSize: 300,
              height: 1,
              color: BloquesPrevia.tintaSobreBloque.withValues(alpha: 0.14),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final int? valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: EspaciadoPrevia.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor == null ? '–' : '$valor',
          style: TextStyle(
            fontFamily: LetraPrevia.titular,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: context.colores.texto,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          etiqueta,
          style: TextStyle(color: context.colores.textoTenue, fontSize: 12),
        ),
      ],
    ),
  );
}

/// Lo que le falta a tu perfil, con un toque para ponerlo.
///
/// El registro ya no lo pide todo de golpe, asi que alguien tiene que
/// recordarlo. Solo aparece mientras falte algo y desaparece sola.
class TarjetaCompletarPerfil extends StatelessWidget {
  const TarjetaCompletarPerfil({
    super.key,
    required this.faltaFoto,
    required this.faltanRedes,
    required this.faltaBio,
    required this.onTap,
  });

  final bool faltaFoto;
  final bool faltanRedes;
  final bool faltaBio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!faltaFoto && !faltanRedes && !faltaBio) return const SizedBox.shrink();
    const tinta = BloquesPrevia.tintaSobreBloque;
    final hechas = [!faltaFoto, !faltanRedes, !faltaBio].where((x) => x).length;

    Widget paso(String texto, bool hecho) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hecho ? tinta : tinta.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hecho ? Icons.check_rounded : Icons.add_rounded,
            size: 15,
            color: hecho ? BloquesPrevia.lila : tinta,
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: hecho ? BloquesPrevia.lila : tinta,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    return Pulsable(
      onTap: onTap,
      escala: 0.98,
      child: Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: BloquesPrevia.lila,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Titular('Completa tu perfil', tamano: 20, color: tinta),
                ),
                Text(
                  '$hechas/3',
                  style: const TextStyle(
                    color: tinta,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Con foto y redes la gente sabe con quién va a quedar.',
              style: TextStyle(color: tinta.withValues(alpha: 0.8), fontSize: 13),
            ),
            const SizedBox(height: EspaciadoPrevia.s + 2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                paso('Foto', !faltaFoto),
                paso('Redes', !faltanRedes),
                paso('Sobre ti', !faltaBio),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
