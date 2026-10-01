import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/tema.dart';
import '../../data/models/oferta.dart';
import '../../data/repositories/repositorio_auth.dart' show ErrorPrevia;
import '../../data/repositories/repositorio_ofertas.dart';

/// Prefijo del QR de canje, para que un lector sepa que es de Previa.
const esquemaQrCanje = 'previa-canje:';

/// Una oferta en vivo, con su cuenta atras y el boton de canjear.
///
/// Es un bloque de color plano (el menta de "queda sitio") porque una oferta
/// con prisa tiene que verse desde lejos, en una discoteca. La columna, y no
/// una fila, mantiene el boton a ancho completo con el texto al 200%.
class TarjetaOferta extends StatefulWidget {
  const TarjetaOferta({
    super.key,
    required this.oferta,
    required this.onCanjear,
    this.ahora = DateTime.now,
  });

  final Oferta oferta;
  final VoidCallback onCanjear;

  /// El reloj, inyectable: asi las pruebas avanzan el tiempo sin esperar.
  final DateTime Function() ahora;

  @override
  State<TarjetaOferta> createState() => _TarjetaOfertaState();
}

class _TarjetaOfertaState extends State<TarjetaOferta> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Un segundo basta para una cuenta atras de minutos y segundos; menos
    // refrescos gastarian bateria sin que nadie lo note.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.oferta;
    final ahora = widget.ahora();
    final restante = o.restante(ahora);
    final viva = o.activa(ahora);
    final minutos = (restante.inSeconds / 60).ceil();
    const tinta = BloquesPrevia.tintaSobreBloque;

    final estado = !viva
        ? 'Terminada'
        : o.agotada
        ? 'Agotada'
        : o.yaCanjeada
        ? 'Ya la tienes'
        : null;

    // El lector de pantalla no debe cantar cada segundo: se le da un resumen
    // por minutos y el texto que cambia se excluye de su arbol.
    final resumen = [
      'Oferta en vivo: ${o.titulo}',
      ?estado,
      if (viva) 'Termina en ${minutos == 1 ? 'un minuto' : '$minutos minutos'}',
      'Quedan ${o.cuposRestantes} de ${o.cupos} cupos',
    ].join('. ');

    return Container(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      decoration: BoxDecoration(
        color: viva && !o.agotada
            ? BloquesPrevia.menta
            : context.colores.superficieAlta,
        borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            label: resumen,
            excludeSemantics: true,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: viva && !o.agotada ? tinta : context.colores.texto,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.categoria.pegatina,
                    style: const TextStyle(fontSize: 34),
                  ),
                  const SizedBox(width: EspaciadoPrevia.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OFERTA EN VIVO',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          o.titulo,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: EspaciadoPrevia.xs),
                        Text(
                          estado ?? 'Termina en ${textoCuentaAtras(restante)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text('Quedan ${o.cuposRestantes} de ${o.cupos}'),
                        if (o.detalle != null) ...[
                          const SizedBox(height: EspaciadoPrevia.xs),
                          Text(o.detalle!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: o.canjeable(ahora) || (viva && o.yaCanjeada)
                ? widget.onCanjear
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: tinta,
              foregroundColor: Colors.white,
            ),
            child: Text(o.yaCanjeada ? 'VER MI CÓDIGO' : 'CANJEAR'),
          ),
        ],
      ),
    );
  }
}

/// Canjear: pide el codigo de la puerta si la oferta lo exige y ensena el
/// codigo y el QR que se ensenan al personal del local.
Future<void> mostrarCanje(
  BuildContext context, {
  required Oferta oferta,
  VoidCallback? alCanjear,
}) {
  return mostrarHoja<void>(
    context,
    builder: (_) => HojaCanje(oferta: oferta, alCanjear: alCanjear),
  );
}

class HojaCanje extends ConsumerStatefulWidget {
  const HojaCanje({super.key, required this.oferta, this.alCanjear});

  final Oferta oferta;
  final VoidCallback? alCanjear;

  @override
  ConsumerState<HojaCanje> createState() => _HojaCanjeState();
}

class _HojaCanjeState extends ConsumerState<HojaCanje> {
  final _puerta = TextEditingController();
  String? _codigo;
  String? _error;
  bool _enCurso = false;

  bool get _pidePuerta =>
      widget.oferta.verificacion == VerificacionOferta.qr &&
      !widget.oferta.yaCanjeada;

  @override
  void initState() {
    super.initState();
    _codigo = widget.oferta.miCodigo;
    // Ya pulsaste "Canjear": si no hace falta escanear nada, se canjea sin
    // pedir un segundo toque.
    if (_codigo == null && !_pidePuerta) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _canjear());
    }
  }

  @override
  void dispose() {
    _puerta.dispose();
    super.dispose();
  }

  Future<void> _canjear() async {
    if (_enCurso) return;
    setState(() {
      _enCurso = true;
      _error = null;
    });
    try {
      final codigo = await ref
          .read(repositorioOfertasProvider)
          .canjear(widget.oferta.id, codigoPuerta: _puerta.text);
      widget.alCanjear?.call();
      if (mounted) setState(() => _codigo = codigo);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ErrorPrevia
              ? e.mensaje
              : 'No se ha podido canjear. Prueba otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.oferta;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Titular(o.titulo, tamano: 26, lineas: 3),
          const SizedBox(height: EspaciadoPrevia.m),
          if (_codigo != null)
            ..._mostrarCodigo(context, _codigo!)
          else
            ..._pedirCodigo(context),
          const SizedBox(height: EspaciadoPrevia.m),
          Text(
            'Solo para mayores de 18 años.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _pedirCodigo(BuildContext context) => [
    if (_pidePuerta) ...[
      Text(
        'Escanea el QR de la puerta o escribe su código para demostrar que '
        'estás aquí.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: EspaciadoPrevia.m),
      TextField(
        controller: _puerta,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _canjear(),
        decoration: const InputDecoration(labelText: 'Código de la puerta'),
      ),
      const SizedBox(height: EspaciadoPrevia.m),
      FilledButton(
        onPressed: _enCurso ? null : _canjear,
        style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
        child: const Text('CANJEAR'),
      ),
    ] else if (_error == null)
      const Cargando(),
    if (_error != null) ...[
      const SizedBox(height: EspaciadoPrevia.s),
      Semantics(
        liveRegion: true,
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      if (!_pidePuerta)
        TextButton(
          onPressed: _enCurso ? null : _canjear,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Reintentar'),
        ),
    ],
  ];

  List<Widget> _mostrarCodigo(BuildContext context, String codigo) => [
    Text(
      'Enséñalo al personal del local.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: EspaciadoPrevia.m),
    Center(
      child: Semantics(
        label: 'Código QR de canje',
        image: true,
        child: Container(
          padding: const EdgeInsets.all(EspaciadoPrevia.m),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          ),
          // Fondo blanco obligatorio: un QR sobre negro no lo lee ninguna
          // camara.
          child: QrImageView(
            data: '$esquemaQrCanje$codigo',
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    ),
    const SizedBox(height: EspaciadoPrevia.m),
    Semantics(
      label: 'Tu código de canje es $codigo',
      excludeSemantics: true,
      child: Text(
        codigo,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: LetraPrevia.titular,
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
    ),
  ];
}

/// La pastilla sobre la foto del local en ¿Vas?: avisa de que hay una oferta
/// en vivo y la abre. Es pequena a proposito: la foto manda en esa pantalla.
class PastillaOfertaEnVivo extends ConsumerWidget {
  const PastillaOfertaEnVivo({
    super.key,
    required this.localId,
    this.ahora = DateTime.now,
  });

  final String localId;
  final DateTime Function() ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ofertas = ref.watch(ofertasActivasProvider(localId)).valueOrNull;
    final vivas = [
      for (final o in ofertas ?? const <Oferta>[])
        if (o.activa(ahora())) o,
    ];
    if (vivas.isEmpty) return const SizedBox.shrink();
    final texto = vivas.length == 1
        ? vivas.first.titulo
        : '${vivas.length} ofertas en vivo';

    return Semantics(
      button: true,
      label: 'Oferta en vivo: $texto. Toca para verla',
      excludeSemantics: true,
      child: Pulsable(
        onTap: () => mostrarOfertasDelLocal(context, localId, ahora: ahora),
        formaFoco: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: BloquesPrevia.menta,
            borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BloquesPrevia.tintaSobreBloque,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> mostrarOfertasDelLocal(
  BuildContext context,
  String localId, {
  DateTime Function() ahora = DateTime.now,
}) {
  return mostrarHoja<void>(
    context,
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.paddingOf(context).bottom + EspaciadoPrevia.m,
      ),
      child: SeccionOfertas(localId: localId, ahora: ahora),
    ),
  );
}

/// Las ofertas activas del local, una debajo de otra. Vacia si no hay.
class SeccionOfertas extends ConsumerWidget {
  const SeccionOfertas({
    super.key,
    required this.localId,
    this.ahora = DateTime.now,
  });

  final String localId;
  final DateTime Function() ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ofertas = ref.watch(ofertasActivasProvider(localId)).valueOrNull;
    final vivas = [
      for (final o in ofertas ?? const <Oferta>[])
        if (o.activa(ahora())) o,
    ];
    if (vivas.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in vivas)
            Padding(
              padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
              child: TarjetaOferta(
                key: ValueKey(o.id),
                oferta: o,
                ahora: ahora,
                onCanjear: () => mostrarCanje(
                  context,
                  oferta: o,
                  alCanjear: () =>
                      ref.invalidate(ofertasActivasProvider(localId)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
