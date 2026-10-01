import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../party/estados_pantalla.dart';
import 'ilustraciones.dart';
import 'servicio_onboarding.dart';

/// Lo que cuenta cada tarjeta. Datos en lugar de cuatro widgets casi iguales:
/// cambiar un texto o el orden es tocar una lista.
class _Tarjeta {
  const _Tarjeta({
    required this.etiqueta,
    required this.titulo,
    required this.texto,
    required this.tipo,
    required this.descripcionImagen,
  });

  final String etiqueta;
  final String titulo;
  final String texto;
  final TipoIlustracion tipo;
  final String descripcionImagen;
}

const _tarjetas = [
  _Tarjeta(
    etiqueta: 'BIENVENIDA',
    titulo: 'Previas cerca de ti',
    texto:
        'Previa reúne a gente que quiere empezar la noche antes de salir. '
        'Encuentra un plan cerca o abre el tuyo.',
    tipo: TipoIlustracion.previa,
    descripcionImagen: 'Una chincheta de mapa rodeada de personas',
  ),
  _Tarjeta(
    etiqueta: 'PRIVACIDAD',
    titulo: 'Tu sitio, a salvo',
    texto:
        'Ves las previas como círculos aproximados. La dirección exacta '
        'solo se revela cuando el anfitrión te acepta.',
    tipo: TipoIlustracion.privacidad,
    descripcionImagen: 'Un mapa con un círculo que oculta el punto exacto',
  ),
  _Tarjeta(
    etiqueta: 'SEGURIDAD',
    titulo: 'Solo mayores de 18',
    texto:
        'Comprobamos la edad al registrarte. Puedes valorar, bloquear y '
        'denunciar en cualquier momento. Disfruta con cabeza.',
    tipo: TipoIlustracion.seguridad,
    descripcionImagen: 'Un escudo con el texto más dieciocho',
  ),
  _Tarjeta(
    etiqueta: 'UBICACIÓN',
    titulo: '¿Para qué tu ubicación?',
    texto:
        'Solo para ordenar las previas por cercanía mientras usas la app. '
        'No la guardamos ni la compartimos, y puedes usar Previa sin ella.',
    tipo: TipoIlustracion.permiso,
    descripcionImagen: 'Un aviso de permiso de ubicación con una chincheta',
  ),
];

/// Onboarding de tarjetas: una idea por pantalla, una acción principal.
///
/// La última tarjeta explica el permiso de ubicación ANTES de que el sistema
/// lo pida: quien entiende el motivo lo concede más y se siente menos
/// vigilado. Si dice "Ahora no", la app sigue funcionando (mapa por defecto).
class PantallaOnboarding extends StatefulWidget {
  const PantallaOnboarding({super.key, this.solicitarPermiso, this.alTerminar});

  /// Inyectable para pruebas: por defecto pide el permiso real.
  final Future<void> Function()? solicitarPermiso;

  /// Inyectable para pruebas: por defecto navega al inicio.
  final VoidCallback? alTerminar;

  @override
  State<PantallaOnboarding> createState() => _PantallaOnboardingState();
}

class _PantallaOnboardingState extends State<PantallaOnboarding> {
  final _controlador = PageController();
  int _pagina = 0;
  bool _terminando = false;

  bool get _esUltima => _pagina == _tarjetas.length - 1;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _siguiente() async {
    final reducir = MediaQuery.disableAnimationsOf(context);
    await _controlador.nextPage(
      duration: reducir ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pedirPermisoYTerminar() async {
    if (_terminando) return;
    setState(() => _terminando = true);
    try {
      await (widget.solicitarPermiso ?? _pedirPermisoReal)();
    } catch (_) {
      // Si falla o se deniega no pasa nada: el mapa usa el centro por
      // defecto y se puede volver a pedir desde donde haga falta.
    }
    await _terminar();
  }

  Future<void> _pedirPermisoReal() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _terminar() async {
    await ServicioOnboarding.marcarVisto();
    if (!mounted) return;
    if (widget.alTerminar != null) {
      widget.alTerminar!();
    } else {
      context.go(Rutas.inicio);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Saltar siempre visible (salvo en la última, que ya tiene su
            // propia salida); ocupa el hueco para que nada salte de sitio.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: EspaciadoPrevia.s,
                  top: EspaciadoPrevia.xs,
                ),
                child: Visibility(
                  visible: !_esUltima,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: _terminando ? null : _terminar,
                    child: const Text('Saltar'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controlador,
                itemCount: _tarjetas.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (_, i) => _PaginaTarjeta(tarjeta: _tarjetas[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                EspaciadoPrevia.l,
                EspaciadoPrevia.s,
                EspaciadoPrevia.l,
                EspaciadoPrevia.l,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IndicadorPagina(actual: _pagina, total: _tarjetas.length),
                  const SizedBox(height: EspaciadoPrevia.l),
                  if (_esUltima) ...[
                    FilledButton.icon(
                      onPressed: _terminando ? null : _pedirPermisoYTerminar,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Activar ubicación'),
                    ),
                    const SizedBox(height: EspaciadoPrevia.xs),
                    TextButton(
                      onPressed: _terminando ? null : _terminar,
                      child: const Text('Ahora no'),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _siguiente,
                      child: const Text('Siguiente'),
                    ),
                    // Mismo alto que "Ahora no" para que el botón principal
                    // no se mueva al cambiar de tarjeta.
                    const SizedBox(height: EspaciadoPrevia.xs + 48),
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

class _PaginaTarjeta extends StatelessWidget {
  const _PaginaTarjeta({required this.tarjeta});

  final _Tarjeta tarjeta;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final reducir = MediaQuery.disableAnimationsOf(context);

    // Entrada sutil (fundido + ligero desplazamiento) al construirse la
    // página; con "reducir animaciones" aparece directamente.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reducir ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, hijo) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 16),
          child: hijo,
        ),
      ),
      // Con scroll: a letra muy grande el texto no cabe y antes se cortaría.
      child: LayoutBuilder(
        builder: (context, caja) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.l),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: caja.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Ilustracion(
                  tipo: tarjeta.tipo,
                  descripcion: tarjeta.descripcionImagen,
                  altura: (caja.maxHeight * 0.42).clamp(120.0, 260.0),
                ),
                const SizedBox(height: EspaciadoPrevia.l),
                Text(
                  tarjeta.etiqueta,
                  style: textos.labelLarge?.copyWith(
                    color: context.colores.acento,
                    letterSpacing: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: EspaciadoPrevia.s),
                Semantics(
                  header: true,
                  child: Text(tarjeta.titulo, style: textos.displaySmall),
                ),
                const SizedBox(height: EspaciadoPrevia.m),
                Text(
                  tarjeta.texto,
                  style: textos.bodyLarge?.copyWith(
                    color: context.colores.textoSuave,
                  ),
                ),
                if (tarjeta.tipo == TipoIlustracion.seguridad) ...[
                  const SizedBox(height: EspaciadoPrevia.m),
                  const MensajeResponsable(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Puntos de página. La activa se alarga (animado) y todo el conjunto se
/// anuncia como "Paso X de Y": los puntos sueltos no dicen nada a un lector
/// de pantalla.
class _IndicadorPagina extends StatelessWidget {
  const _IndicadorPagina({required this.actual, required this.total});

  final int actual;
  final int total;

  @override
  Widget build(BuildContext context) {
    final reducir = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'Paso ${actual + 1} de $total',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: reducir
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: i == actual ? 28 : 8,
              decoration: BoxDecoration(
                color: i == actual
                    ? context.colores.primarioTexto
                    : context.colores.borde,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
