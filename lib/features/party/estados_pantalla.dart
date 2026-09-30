import 'package:flutter/material.dart';

import '../../app/tema.dart';

/// Indicador de carga con etiqueta para lectores de pantalla.
///
/// Un `CircularProgressIndicator` a secas es mudo para TalkBack/VoiceOver: el
/// usuario no sabe si la pantalla está vacía o está cargando.
class IndicadorCarga extends StatelessWidget {
  const IndicadorCarga({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
      );
}

/// Contenedor común de los estados de error y vacío.
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
              const ExcludeSemantics(
                child: Icon(Icons.cloud_off,
                    size: 40, color: ColoresPrevia.textoTenue),
              ),
              const SizedBox(height: EspaciadoPrevia.m),
              Text(mensaje,
                  style: textos.titleLarge, textAlign: TextAlign.center),
              if (detalle != null) ...[
                const SizedBox(height: EspaciadoPrevia.xs),
                Text(detalle!,
                    textAlign: TextAlign.center, style: textos.bodyMedium),
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

/// Estado vacío útil: explica por qué no hay nada y propone qué hacer.
///
/// Las [acciones] son botones ya construidos (el primero debería ser el
/// principal): "Nada por aquí" a secas es un callejón sin salida, sobre todo
/// en un mercado de dos lados con pocos usuarios.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.acciones = const [],
    this.controlador,
    this.compacto = false,
  });

  /// En hojas bajas (la lista del mapa, que arranca al 26 % de la pantalla)
  /// se quita el icono para que el título y el primer botón se vean sin
  /// tener que desplazar.
  final bool compacto;

  final IconData icono;
  final String titulo;
  final String detalle;
  final List<Widget> acciones;
  final ScrollController? controlador;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return _CuerpoEstado(
      controlador: controlador,
      hijos: [
        if (!compacto) ...[
          ExcludeSemantics(
            child: Icon(icono, size: 40, color: ColoresPrevia.textoTenue),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
        ],
        Semantics(
          header: true,
          child: Text(titulo,
              style: textos.titleLarge, textAlign: TextAlign.center),
        ),
        const SizedBox(height: EspaciadoPrevia.xs),
        Text(detalle, textAlign: TextAlign.center, style: textos.bodyMedium),
        for (var i = 0; i < acciones.length; i++) ...[
          SizedBox(height: i == 0 ? EspaciadoPrevia.m : EspaciadoPrevia.s),
          acciones[i],
        ],
      ],
    );
  }
}

/// Aviso de error de formulario o de acción.
///
/// `liveRegion` hace que el lector de pantalla lo lea en cuanto aparece, sin
/// que el usuario tenga que buscarlo. Lleva icono y texto (no solo color).
class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: ColoresPrevia.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(color: ColoresPrevia.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.error_outline,
                  color: ColoresPrevia.error, size: 20),
            ),
            const SizedBox(width: EspaciadoPrevia.s),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(color: ColoresPrevia.error, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
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
