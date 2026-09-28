import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/models/cara.dart';
import 'colores.dart';
import 'movimiento.dart';
import 'tema.dart' show BloquesPrevia, LetraPrevia;

/// La cara de alguien, en redondo.
///
/// Sin foto no se queda en un circulo gris: toma uno de los bloques de color
/// segun el nombre, con la inicial en la letra gorda. Asi una lista de gente
/// sin foto sigue pareciendo gente y no huecos, y la misma persona sale
/// siempre del mismo color.
class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({
    super.key,
    required this.url,
    required this.inicial,
    this.lado = 40,
    this.anillo,
  });

  final String? url;

  /// El nombre entero vale: se usa su primera letra y su color.
  final String inicial;
  final double lado;

  /// Color del aro exterior. Nulo es sin aro.
  final Color? anillo;

  @override
  Widget build(BuildContext context) {
    final letra = inicial.trim().isNotEmpty
        ? inicial.trim()[0].toUpperCase()
        : '?';
    final bloque = BloquesPrevia.deIndice(inicial.hashCode.abs());

    final sinFoto = Container(
      color: bloque,
      alignment: Alignment.center,
      child: Text(
        letra,
        style: TextStyle(
          fontFamily: LetraPrevia.titular,
          fontWeight: FontWeight.w900,
          fontSize: lado * 0.46,
          height: 1,
          color: BloquesPrevia.tintaSobreBloque,
        ),
      ),
    );

    final cara = ClipOval(
      child: SizedBox.square(
        dimension: lado,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                fadeInDuration: MovimientoPrevia.rapido,
                placeholder: (_, _) =>
                    ColoredBox(color: context.colores.superficieActiva),
                errorWidget: (_, _, _) => sinFoto,
              )
            : sinFoto,
      ),
    );

    if (anillo == null) return cara;
    // El aro va separado de la foto por una linea del color del fondo, como
    // las historias: pegado a la foto se confunde con ella.
    return Container(
      padding: EdgeInsets.all(lado > 60 ? 3 : 2),
      decoration: BoxDecoration(color: anillo, shape: BoxShape.circle),
      child: Container(
        padding: EdgeInsets.all(lado > 60 ? 3 : 1.5),
        decoration: BoxDecoration(
          color: context.colores.fondo,
          shape: BoxShape.circle,
        ),
        child: cara,
      ),
    );
  }
}

/// Caras solapadas, como las de "a X y 4 mas les gusta".
///
/// Es la forma mas corta de decir "va gente" sin escribir un numero: se ve
/// antes de leer nada.
class PilaDeCaras extends StatelessWidget {
  const PilaDeCaras({
    super.key,
    required this.caras,
    this.lado = 30,
    this.maximo = 4,
    this.resto = 0,
    this.borde,
  });

  final List<Cara> caras;
  final double lado;
  final int maximo;

  /// Cuanta gente mas hay aparte de las caras que se ven.
  final int resto;

  /// El color que separa una cara de la siguiente. Debe ser el del fondo
  /// sobre el que va la pila.
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    final visibles = caras.take(maximo).toList();
    final separador = borde ?? context.colores.fondo;
    final paso = lado * 0.68;
    final fichas = visibles.length + (resto > 0 ? 1 : 0);
    if (fichas == 0) return const SizedBox.shrink();

    Widget conBorde(Widget hijo) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: separador, shape: BoxShape.circle),
      child: hijo,
    );

    return SizedBox(
      height: lado + 4,
      width: paso * (fichas - 1) + lado + 4,
      child: Stack(
        children: [
          for (var i = 0; i < visibles.length; i++)
            Positioned(
              left: paso * i,
              child: conBorde(
                AvatarPerfil(
                  url: visibles[i].avatar,
                  inicial: visibles[i].nombre,
                  lado: lado,
                ),
              ),
            ),
          if (resto > 0)
            Positioned(
              left: paso * visibles.length,
              child: conBorde(
                Container(
                  width: lado,
                  height: lado,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.colores.superficieActiva,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '+$resto',
                    style: TextStyle(
                      fontFamily: LetraPrevia.titular,
                      fontWeight: FontWeight.w800,
                      fontSize: lado * 0.36,
                      color: context.colores.texto,
                      fontFeatures: const [FontFeature.tabularFigures()],
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
