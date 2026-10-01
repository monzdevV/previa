import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tema.dart';
import '../../data/repositories/repositorio_calendario.dart';
import '../social/pantalla_resumen_noche.dart';
import 'proveedores_perfil.dart';

/// Cuantos meses hacia atras se puede deslizar. Dos años bastan para "¿cuando
/// fue aquello?" y acotan lo que se puede descargar del perfil de otro.
const _mesesAtras = 24;

/// El calendario de cuando ha salido alguien, con una foto por noche.
///
/// Es la parte del perfil que cuenta como es alguien de un vistazo: si sale
/// cada finde o una vez al mes, y con que noches. Por eso cada dia lleva su
/// foto y no un punto: un punto dice "salio", la foto dice como fue.
class CalendarioSocial extends StatefulWidget {
  const CalendarioSocial({
    super.key,
    required this.perfilId,
    this.esMio = false,
  });

  final String perfilId;

  /// En tu calendario cada noche abre su resumen completo.
  final bool esMio;

  @override
  State<CalendarioSocial> createState() => _CalendarioSocialState();
}

class _CalendarioSocialState extends State<CalendarioSocial> {
  final _paginas = PageController();
  int _pagina = 0;

  DateTime get _hoy => DateTime.now();

  DateTime _mesDe(int pagina) => DateTime(_hoy.year, _hoy.month - pagina);

  void _ir(int pagina) {
    if (pagina < 0 || pagina > _mesesAtras) return;
    if (MovimientoPrevia.reducido(context)) {
      _paginas.jumpToPage(pagina);
    } else {
      _paginas.animateToPage(
        pagina,
        duration: MovimientoPrevia.normal,
        curve: MovimientoPrevia.curva,
      );
    }
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mes = _mesDe(_pagina);
    final c = context.colores;
    final nombreMes = DateFormat('MMMM', 'es_ES').format(mes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: MovimientoPrevia.rapido,
                    child: Row(
                      key: ValueKey(mes),
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Titular(nombreMes, tamano: 28),
                        if (mes.year != _hoy.year) ...[
                          const SizedBox(width: EspaciadoPrevia.s),
                          Text(
                            '${mes.year}',
                            style: TextStyle(
                              color: c.textoTenue,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  _Recuento(perfilId: widget.perfilId, mes: mes),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: _pagina < _mesesAtras ? () => _ir(_pagina + 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: _pagina > 0 ? () => _ir(_pagina - 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        const _DiasDeLaSemana(),
        const SizedBox(height: EspaciadoPrevia.s),
        LayoutBuilder(
          builder: (context, limites) {
            const hueco = 5.0;
            final ancho = (limites.maxWidth - hueco * 6) / 7;
            final alto = ancho * 1.22;
            // El alto sigue a las filas del mes que se ve, con una
            // transicion: fijo a seis dejaba un hueco en los meses de cinco,
            // y sin transicion la pagina daba un salto al deslizar.
            final primero = DateTime(mes.year, mes.month);
            final filas =
                ((primero.weekday -
                            1 +
                            DateTime(mes.year, mes.month + 1, 0).day) /
                        7)
                    .ceil();
            return AnimatedContainer(
              duration: MovimientoPrevia.reducido(context)
                  ? Duration.zero
                  : MovimientoPrevia.normal,
              curve: MovimientoPrevia.curva,
              height: alto * filas + hueco * (filas - 1),
              child: PageView.builder(
                controller: _paginas,
                // Hacia la derecha se va al pasado, como en cualquier
                // calendario de movil.
                reverse: true,
                itemCount: _mesesAtras + 1,
                onPageChanged: (p) => setState(() => _pagina = p),
                itemBuilder: (_, p) => _Mes(
                  perfilId: widget.perfilId,
                  mes: _mesDe(p),
                  esMio: widget.esMio,
                  anchoCelda: ancho,
                  altoCelda: alto,
                  hueco: hueco,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Recuento extends ConsumerWidget {
  const _Recuento({required this.perfilId, required this.mes});

  final String perfilId;
  final DateTime mes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noches = ref.watch(calendarioProvider((perfilId, mes)));
    final texto = noches.when(
      loading: () => ' ',
      error: (_, _) => 'No se ha podido cargar',
      data: (lista) => switch (lista.length) {
        0 => 'Ninguna noche este mes',
        1 => '1 noche',
        final n => '$n noches',
      },
    );
    return Text(
      texto,
      style: TextStyle(
        color: context.colores.textoSuave,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DiasDeLaSemana extends StatelessWidget {
  const _DiasDeLaSemana();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final d in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
        Expanded(
          child: Text(
            d,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.colores.textoTenue,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

class _Mes extends ConsumerWidget {
  const _Mes({
    required this.perfilId,
    required this.mes,
    required this.esMio,
    required this.anchoCelda,
    required this.altoCelda,
    required this.hueco,
  });

  final String perfilId;
  final DateTime mes;
  final bool esMio;
  final double anchoCelda;
  final double altoCelda;
  final double hueco;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(calendarioProvider((perfilId, mes)));
    final porDia = {
      for (final n in datos.valueOrNull ?? const <NocheDelCalendario>[])
        n.noche.day: n,
    };

    final primero = DateTime(mes.year, mes.month);
    // Lunes primero: el finde queda junto al final de la fila, que es donde
    // se agrupan las fotos y se ve el ritmo.
    final desfase = primero.weekday - 1;
    final dias = DateTime(mes.year, mes.month + 1, 0).day;
    final hoy = DateTime.now();
    final reducido = MovimientoPrevia.reducido(context);

    var orden = 0;
    return Wrap(
      spacing: hueco,
      runSpacing: hueco,
      children: [
        for (var i = 0; i < desfase; i++)
          SizedBox(width: anchoCelda, height: altoCelda),
        for (var dia = 1; dia <= dias; dia++)
          Builder(
            builder: (context) {
              final noche = porDia[dia];
              final esHoy =
                  hoy.year == mes.year &&
                  hoy.month == mes.month &&
                  hoy.day == dia;
              final futuro = DateTime(mes.year, mes.month, dia).isAfter(hoy);
              Widget celda = _Celda(
                dia: dia,
                noche: noche,
                esHoy: esHoy,
                futuro: futuro,
                ancho: anchoCelda,
                alto: altoCelda,
                onTap: noche == null
                    ? null
                    : () => _verNoche(context, noche, esMio),
              );
              if (noche != null && !reducido) {
                celda = celda
                    .animate(delay: (30 * (orden++).clamp(0, 12)).ms)
                    .fadeIn(duration: MovimientoPrevia.normal)
                    .scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      curve: MovimientoPrevia.curva,
                      duration: MovimientoPrevia.normal,
                    );
              }
              return celda;
            },
          ),
      ],
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.dia,
    required this.noche,
    required this.esHoy,
    required this.futuro,
    required this.ancho,
    required this.alto,
    required this.onTap,
  });

  final int dia;
  final NocheDelCalendario? noche;
  final bool esHoy;
  final bool futuro;
  final double ancho;
  final double alto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final n = noche;
    final radio = BorderRadius.circular(ancho * 0.26);

    if (n == null) {
      return Container(
        width: ancho,
        height: alto,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radio,
          border: esHoy ? Border.all(color: c.primarioTexto, width: 2) : null,
        ),
        child: Text(
          '$dia',
          style: TextStyle(
            color: esHoy
                ? c.primarioTexto
                : futuro
                ? c.textoTenue.withValues(alpha: 0.45)
                : c.textoTenue,
            fontSize: 13,
            fontWeight: esHoy ? FontWeight.w800 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    final color = BloquesPrevia.deIndice(
      (n.sitios.isEmpty ? '' : n.sitios.first).hashCode.abs(),
    );
    final fondo = n.portada != null
        ? CachedNetworkImage(
            imageUrl: n.portada!,
            fit: BoxFit.cover,
            memCacheWidth: 200,
            fadeInDuration: MovimientoPrevia.rapido,
            placeholder: (_, _) => ColoredBox(color: c.superficieActiva),
            errorWidget: (_, _, _) => ColoredBox(color: color),
          )
        : ColoredBox(
            color: color,
            child: Center(
              child: Text(
                n.sitios.isEmpty ? '·' : n.sitios.first.characters.first,
                style: TextStyle(
                  fontFamily: LetraPrevia.titular,
                  fontWeight: FontWeight.w900,
                  fontSize: ancho * 0.5,
                  color: BloquesPrevia.tintaSobreBloque.withValues(alpha: 0.85),
                ),
              ),
            ),
          );

    return Semantics(
      button: true,
      label: 'Día $dia: ${n.donde}',
      excludeSemantics: true,
      child: Pulsable(
        onTap: onTap,
        escala: 0.92,
        child: Container(
          width: ancho,
          height: alto,
          decoration: BoxDecoration(
            borderRadius: radio,
            border: esHoy ? Border.all(color: c.primario, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: radio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                fondo,
                // El numero sigue a la vista sobre la foto: sin el, el mes
                // se convierte en un mosaico y ya no se sabe que dia fue.
                if (n.portada != null)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  left: 6,
                  child: Text(
                    '$dia',
                    style: TextStyle(
                      color: n.portada != null
                          ? Colors.white
                          : BloquesPrevia.tintaSobreBloque,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La noche de un dia, en grande.
Future<void> _verNoche(
  BuildContext context,
  NocheDelCalendario noche,
  bool esMio,
) {
  final fecha = DateFormat("EEEE d 'de' MMMM", 'es_ES').format(noche.noche);
  return mostrarHoja<void>(
    context,
    builder: (contexto) {
      final c = contexto.colores;
      final alto = MediaQuery.sizeOf(contexto).height;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          EspaciadoPrevia.m,
          0,
          EspaciadoPrevia.m,
          EspaciadoPrevia.m + MediaQuery.paddingOf(contexto).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noche.portada != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: alto * 0.45),
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      EspaciadoPrevia.radioGrande,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: noche.portada!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          ColoredBox(color: c.superficieActiva),
                      errorWidget: (_, _, _) =>
                          ColoredBox(color: c.superficieActiva),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: EspaciadoPrevia.m),
            Text(
              fecha[0].toUpperCase() + fecha.substring(1),
              style: TextStyle(
                color: c.textoSuave,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Titular(noche.donde, tamano: 30, lineas: 3),
            if (noche.fotos > 0) ...[
              const SizedBox(height: EspaciadoPrevia.s),
              Text(
                noche.fotos == 1
                    ? '1 foto esa noche'
                    : '${noche.fotos} fotos esa noche',
                style: TextStyle(
                  color: c.primarioTexto,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (esMio) ...[
              const SizedBox(height: EspaciadoPrevia.l),
              FilledButton(
                onPressed: () {
                  Navigator.of(contexto).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PantallaResumenNoche(noche: noche.noche),
                    ),
                  );
                },
                child: const Text('VER LA NOCHE'),
              ),
            ],
          ],
        ),
      );
    },
  );
}
