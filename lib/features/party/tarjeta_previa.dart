import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/models/previa.dart';

/// Tarjeta de una previa en el feed.
///
/// Lleva la imagen delante porque es lo que hace que una app social se sienta
/// como tal: primero ves el sitio y la cara de quien lo abre, y solo despues
/// lees los datos. Mientras no haya foto subida, el hueco se rellena con el
/// degradado de marca y la inicial del anfitrion, que es lo que hace
/// cualquier app cuando le falta la portada.
class TarjetaPrevia extends StatelessWidget {
  const TarjetaPrevia({
    super.key,
    required this.previa,
    this.onTap,
    this.compacta = false,
  });

  final Previa previa;
  final VoidCallback? onTap;

  /// En la hoja del mapa el alto es oro: la imagen se encoge y la descripcion
  /// desaparece, pero la cara y las plazas se quedan.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hora = DateFormat('HH:mm', 'es_ES').format(previa.empiezaEn);
    final ocupacion = Ocupacion.desde(previa.plazasLibres);

    return Material(
      color: context.colores.superficie,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Portada(
              previa: previa,
              hora: hora,
              ocupacion: ocupacion,
              alto: compacta ? 116 : 188,
            ),

            Padding(
              padding: const EdgeInsets.all(EspaciadoPrevia.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    previa.titulo,
                    style: textos.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: EspaciadoPrevia.xs),
                  Text(
                    [
                      previa.zona,
                      if (previa.distanciaLegible.isNotEmpty)
                        previa.distanciaLegible,
                      previa.cuandoEmpieza,
                    ].join(' · '),
                    style: textos.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (!compacta &&
                      previa.descripcion != null &&
                      previa.descripcion!.isNotEmpty) ...[
                    const SizedBox(height: EspaciadoPrevia.s),
                    Text(
                      previa.descripcion!,
                      style: textos.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  if (previa.ambiente.isNotEmpty) ...[
                    const SizedBox(height: EspaciadoPrevia.s + EspaciadoPrevia.xs),
                    Wrap(
                      spacing: EspaciadoPrevia.xs + 2,
                      runSpacing: EspaciadoPrevia.xs + 2,
                      children: [
                        for (final etiqueta in previa.ambiente.take(3))
                          _Etiqueta(etiqueta),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Portada extends StatelessWidget {
  const _Portada({
    required this.previa,
    required this.hora,
    required this.ocupacion,
    required this.alto,
  });

  final Previa previa;
  final String hora;
  final Ocupacion ocupacion;
  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Fondo(previa: previa),

          // Velo inferior: sin el, el texto blanco se pierde en cuanto haya
          // fotos reales y claras.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.45, 1],
              ),
            ),
          ),

          Positioned(
            top: EspaciadoPrevia.s + EspaciadoPrevia.xs,
            right: EspaciadoPrevia.s + EspaciadoPrevia.xs,
            child: _PastillaPlazas(ocupacion: ocupacion, libres: previa.plazasLibres),
          ),

          Positioned(
            left: EspaciadoPrevia.m,
            right: EspaciadoPrevia.m,
            bottom: EspaciadoPrevia.s + EspaciadoPrevia.xs,
            child: Row(
              children: [
                _Avatar(previa: previa),
                const SizedBox(width: EspaciadoPrevia.s),
                Expanded(
                  child: Text(
                    previa.anfitrionNombre,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  hora,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de la previa cuando exista; mientras tanto, degradado de marca.
class _Fondo extends StatelessWidget {
  const _Fondo({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final foto = previa.anfitrionAvatar;
    if (foto != null && foto.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: foto,
        fit: BoxFit.cover,
        placeholder: (_, _) => ColoredBox(color: context.colores.superficieAlta),
        errorWidget: (_, _, _) => const _Relleno(),
      );
    }
    return const _Relleno();
  }
}

class _Relleno extends StatelessWidget {
  const _Relleno();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: context.colores.degradado),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.previa});

  final Previa previa;

  @override
  Widget build(BuildContext context) {
    final inicial = previa.anfitrionNombre.isNotEmpty
        ? previa.anfitrionNombre[0].toUpperCase()
        : '?';

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colores.superficieActiva,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        inicial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PastillaPlazas extends StatelessWidget {
  const _PastillaPlazas({required this.ocupacion, required this.libres});

  final Ocupacion ocupacion;
  final int libres;

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (ocupacion) {
      Ocupacion.completa => 'Completa',
      _ => libres == 1 ? '1 plaza' : '$libres plazas',
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        vertical: EspaciadoPrevia.xs + 2,
      ),
      decoration: BoxDecoration(
        color: ocupacion.viva
            ? ocupacion.color(context.colores)
            : const Color(0xCC000000),
        borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ocupacion.viva) ...[
            const _Punto(),
            const SizedBox(width: EspaciadoPrevia.xs + 1),
          ],
          Text(
            etiqueta,
            style: TextStyle(
              color: ocupacion.viva
                  ? const Color(0xFF07130C)
                  : context.colores.textoSuave,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// El punto de "en directo": lo que dice de un vistazo que ahi se puede entrar.
class _Punto extends StatelessWidget {
  const _Punto();

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: const BoxDecoration(
      color: Color(0xFF07130C),
      shape: BoxShape.circle,
    ),
  );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: EspaciadoPrevia.s + EspaciadoPrevia.xs,
      vertical: EspaciadoPrevia.xs + 1,
    ),
    decoration: BoxDecoration(
      color: context.colores.superficieAlta,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: context.colores.textoSuave,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
