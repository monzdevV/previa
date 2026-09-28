import 'dart:ui';

import 'package:flutter/material.dart';

import 'colores.dart';
import 'movimiento.dart';
import 'tema.dart' show EspaciadoPrevia;

/// Vidrio: lo que flota encima de una foto o del mapa.
///
/// Solo para eso. Una tarjeta sobre el fondo negro no gana nada siendo
/// translucida, porque detras no hay nada que dejar ver; el vidrio tiene
/// sentido cuando el contenido pasa por debajo (la barra de pestañas sobre
/// el feed, los controles sobre el mapa). Usado en todo, deja de significar
/// "esto esta por encima".
///
/// Quien pide mas contraste en el sistema lo recibe opaco: el desenfoque
/// baja la legibilidad del texto que lleva encima.
class Cristal extends StatelessWidget {
  const Cristal({
    super.key,
    required this.child,
    this.radio = EspaciadoPrevia.pastilla,
    this.padding = EdgeInsets.zero,
    this.forma = BoxShape.rectangle,
    this.sombra = true,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final BoxShape forma;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final opaco = MediaQuery.highContrastOf(context);
    final borde = forma == BoxShape.circle
        ? null
        : BorderRadius.circular(radio);

    final contenido = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: opaco ? c.superficieAlta : c.cristal,
        shape: forma,
        borderRadius: borde,
        // Un filo de luz arriba: es lo que separa el vidrio de un gris plano.
        border: Border.all(color: c.bordeCristal, width: 0.8),
      ),
      child: child,
    );

    final recortado = forma == BoxShape.circle
        ? ClipOval(child: _desenfocar(contenido, opaco))
        : ClipRRect(borderRadius: borde!, child: _desenfocar(contenido, opaco));

    if (!sombra) return recortado;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: forma,
        borderRadius: borde,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: recortado,
    );
  }

  Widget _desenfocar(Widget hijo, bool opaco) => opaco
      ? hijo
      : BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: hijo,
        );
}

/// Boton redondo de vidrio para los controles que flotan.
class BotonCristal extends StatelessWidget {
  const BotonCristal({
    super.key,
    required this.icono,
    required this.onTap,
    required this.etiqueta,
    this.activo = false,
    this.lado = 48,
  });

  final IconData icono;
  final VoidCallback? onTap;

  /// Lo que lee el lector de pantalla y sale al mantener pulsado.
  final String etiqueta;

  /// Un filtro puesto, por ejemplo: se rellena de amarillo.
  final bool activo;
  final double lado;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final icono = Icon(
      this.icono,
      size: lado * 0.44,
      color: activo ? c.sobrePrimario : c.texto,
    );

    return Tooltip(
      message: etiqueta,
      child: Semantics(
        button: true,
        label: etiqueta,
        excludeSemantics: true,
        child: Pulsable(
          onTap: onTap,
          escala: 0.92,
          child: SizedBox.square(
            dimension: lado,
            child: activo
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.primario,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: icono),
                  )
                : Cristal(forma: BoxShape.circle, child: Center(child: icono)),
          ),
        ),
      ),
    );
  }
}

/// Pastilla de vidrio con icono y texto: la ciudad sobre el mapa, el resumen
/// de lo que hay cerca.
class PastillaCristal extends StatelessWidget {
  const PastillaCristal({
    super.key,
    required this.texto,
    this.icono,
    this.onTap,
    this.cargando = false,
    this.alto = 44,
  });

  final String texto;
  final IconData? icono;
  final VoidCallback? onTap;
  final bool cargando;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final pastilla = Cristal(
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
      child: SizedBox(
        height: alto,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cargando)
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.textoSuave,
                ),
              )
            else if (icono != null)
              Icon(icono, size: 18, color: c.primarioTexto),
            if (cargando || icono != null)
              const SizedBox(width: EspaciadoPrevia.s),
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: EspaciadoPrevia.xs),
              Icon(Icons.expand_more_rounded, size: 18, color: c.textoSuave),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return pastilla;
    return Pulsable(onTap: onTap, child: pastilla);
  }
}

/// Abre una hoja inferior con el aspecto de la casa.
///
/// Todas las hojas de la app pasan por aqui para que se abran igual, tengan
/// el mismo asa y respeten la zona segura: hechas cada una a mano, cada
/// pantalla acababa con su version.
Future<T?> mostrarHoja<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool arrastrable = false,
  double altoInicial = 0.6,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: !arrastrable,
    builder: arrastrable
        ? (contexto) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: altoInicial,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            snap: true,
            builder: (_, controlador) => PrimaryScrollController(
              controller: controlador,
              child: builder(contexto),
            ),
          )
        : builder,
  );
}
