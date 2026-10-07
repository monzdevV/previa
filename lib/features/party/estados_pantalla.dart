import 'package:flutter/material.dart';

import '../../app/tema.dart';

// El estado vacío y el indicador de carga viven en `app/componentes.dart`
// (`EstadoVacio`, `Cargando`) y el aviso de formulario en `piezas_acceso.dart`:
// aquí solo queda lo que la app local no tenía, el estado de error.

/// Contenedor común de los estados de error.
///
/// Con [controlador] se pinta dentro de un `ListView`: es lo que necesita la
/// hoja deslizable del mapa (si no, al arrastrarla a su altura mínima el
/// contenido desbordaría). Sin él, se centra y permite scroll, de modo que
/// con `textScaler` grande nunca se recorta ni da overflow.
class _CuerpoEstado extends StatelessWidget {
  const _CuerpoEstado({required this.hijos, this.controlador});

  final List<Widget> hijos;
  final ScrollController? controlador;

  @override
  Widget build(BuildContext context) {
    final columna = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: hijos,
    );
    const relleno = EdgeInsets.all(EspaciadoPrevia.l);

    if (controlador != null) {
      return ListView(
        controller: controlador,
        padding: relleno,
        children: [columna],
      );
    }
    return Center(
      child: SingleChildScrollView(padding: relleno, child: columna),
    );
  }
}

/// Estado de error con botón "Reintentar".
///
/// Un mensaje de error sin salida deja al usuario atascado; además se marca
/// como `liveRegion` para que el lector de pantalla lo anuncie al aparecer.
class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
    this.detalle,
    this.controlador,
  });

  final String mensaje;
  final String? detalle;
  final VoidCallback onReintentar;
  final ScrollController? controlador;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return _CuerpoEstado(
      controlador: controlador,
      hijos: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.cloud_off,
                  size: 40,
                  color: context.colores.textoTenue,
                ),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(
                mensaje,
                style: textos.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (detalle != null) ...[
                const SizedBox(height: EspaciadoPrevia.xs),
                Text(
                  detalle!,
                  textAlign: TextAlign.center,
                  style: textos.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        OutlinedButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

/// Recordatorio corto de edad y consumo. Una sola fuente para que el texto
/// sea idéntico en bienvenida, registro y mapa (las tiendas piden coherencia
/// con la clasificación por edad).
const mensajeResponsable = 'Solo +18. Disfruta con cabeza.';

class MensajeResponsable extends StatelessWidget {
  const MensajeResponsable({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: EspaciadoPrevia.s),
      child: Text(
        mensajeResponsable,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
      ),
    );
  }
}
