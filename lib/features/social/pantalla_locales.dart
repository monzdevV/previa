import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/local.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_social.dart';
import '../juego/no_hay_huevos.dart' show StickerNoHayHuevos;
import '../profile/proveedores_perfil.dart';
import 'pantalla_sala.dart';
import 'selector_vas.dart';

/// Ciudad que se esta mirando. Se queda fijada mientras dure la sesion.
class CiudadDeLaNoche extends Notifier<String> {
  @override
  String build() => 'Zaragoza';

  void fijar(String ciudad) {
    final limpia = ciudad.trim();
    if (limpia.isNotEmpty) state = limpia;
  }
}

final ciudadDeLaNocheProvider = NotifierProvider<CiudadDeLaNoche, String>(
  CiudadDeLaNoche.new,
);

final localesProvider = FutureProvider<List<Local>>((ref) async {
  final ciudad = ref.watch(ciudadDeLaNocheProvider);
  return ref.watch(repositorioSocialProvider).localesDeLaNoche(ciudad);
});

/// ¿Quien va esta noche?
///
/// No es un listado de discotecas, que eso ya existe en cualquier guia: es
/// ver quien sale y donde. Una cara conocida en un sitio decide la noche mas
/// que la musica, asi que cada local es un cartel con las caras de quien va
/// y la pregunta a un toque.
class PantallaLocales extends ConsumerWidget {
  const PantallaLocales({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locales = ref.watch(localesProvider);
    final ciudad = ref.watch(ciudadDeLaNocheProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: context.colores.primarioTexto,
        backgroundColor: context.colores.superficie,
        // El fallo se traga aqui porque ya lo pinta la propia lista.
        onRefresh: () => ref
            .refresh(localesProvider.future)
            .then((_) {}, onError: (_) {}),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: _Cabecera(
                  ciudad: ciudad,
                  locales: locales.valueOrNull,
                ),
              ),
            ),
            ...locales.when(
              loading: () => [const _Esqueletos()],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EstadoVacio(
                    icono: Icons.cloud_off_rounded,
                    titulo: 'Sin conexión',
                    detalle: 'No hemos podido ver quién sale. Desliza hacia '
                        'abajo o reinténtalo.',
                    accion: 'Reintentar',
                    onAccion: () => ref.invalidate(localesProvider),
                  ),
                ),
              ],
              data: (lista) => lista.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EstadoVacio(
                          pegatina: '🪩',
                          titulo: 'Aún no hay sitios en $ciudad',
                          detalle:
                              'Añade el primero y que la gente pueda decir '
                              'que va.',
                          accion: 'Añadir un sitio',
                          onAccion: () => _proponerLocal(context, ref, ciudad),
                        ),
                      ),
                    ]
                  : [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          EspaciadoPrevia.m,
                          EspaciadoPrevia.s,
                          EspaciadoPrevia.m,
                          0,
                        ),
                        sliver: SliverList.separated(
                          itemCount: lista.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: EspaciadoPrevia.m + 4),
                          itemBuilder: (_, i) {
                            final ficha = FichaLocal(
                              key: ValueKey(lista[i].id),
                              local: lista[i],
                              color: BloquesPrevia.deIndice(i),
                            );
                            if (MovimientoPrevia.reducido(context)) {
                              return ficha;
                            }
                            return ficha
                                .animate(delay: MovimientoPrevia.retrasoDe(i))
                                .fadeIn(duration: MovimientoPrevia.normal)
                                .moveY(
                                  begin: 16,
                                  end: 0,
                                  curve: MovimientoPrevia.curva,
                                );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            EspaciadoPrevia.m,
                            EspaciadoPrevia.l,
                            EspaciadoPrevia.m,
                            0,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _proponerLocal(context, ref, ciudad),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('¿Falta tu sitio? Añádelo'),
                          ),
                        ),
                      ),
                    ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: context.holguraInferior + EspaciadoPrevia.m,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.ciudad, required this.locales});

  final String ciudad;
  final List<Local>? locales;

  @override
  Widget build(BuildContext context) {
    final lista = locales ?? const <Local>[];
    final salen = lista.fold<int>(0, (t, l) => t + l.van);
    final dentro = lista.fold<int>(0, (t, l) => t + l.aqui);

    final resumen = locales == null
        ? ' '
        : salen == 0
        ? 'Nadie ha dicho nada todavía. Sé la primera persona.'
        : [
            salen == 1 ? '1 persona sale' : '$salen personas salen',
            if (dentro > 0) '$dentro ya están dentro',
          ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        EspaciadoPrevia.s,
        EspaciadoPrevia.m,
        EspaciadoPrevia.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La ciudad es lo unico que se toca arriba: el resto de la pantalla
          // es contenido, no controles.
          Consumer(
            builder: (context, ref, _) => PastillaCristal(
              icono: Icons.place_rounded,
              texto: ciudad,
              onTap: () => _cambiarCiudad(context, ref, ciudad),
              desplegable: true,
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.l),
          const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Titular('¿Quién va\nesta noche?', tamano: 48),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          AnimatedSwitcher(
            duration: MovimientoPrevia.rapido,
            child: Text(
              resumen,
              key: ValueKey(resumen),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colores.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un local como cartel: el nombre enorme, quien va y la pregunta.
class FichaLocal extends ConsumerStatefulWidget {
  const FichaLocal({super.key, required this.local, required this.color});

  final Local local;

  /// Cada local es un cartel de un color; rotan para que dos seguidos no se
  /// confundan.
  final Color color;

  @override
  ConsumerState<FichaLocal> createState() => _FichaLocalState();
}

class _FichaLocalState extends ConsumerState<FichaLocal> {
  late Local _l = widget.local;

  /// Mientras la peticion no vuelve se ignoran los toques: dos seguidos
  /// descuadrarian los contadores, que se calculan en local.
  bool _enCurso = false;

  @override
  void didUpdateWidget(covariant FichaLocal anterior) {
    super.didUpdateWidget(anterior);
    // Al recargar la lista manda lo que dice el servidor, no la copia que se
    // tomo la primera vez que se pinto la ficha.
    if (!_enCurso && anterior.local != widget.local) _l = widget.local;
  }

  Future<void> _decir(EstadoNoche? estado) async {
    if (_enCurso) return;
    final antes = _l;
    final mensajero = ScaffoldMessenger.of(context);
    setState(() {
      _enCurso = true;
      _l = _l.conMiEstado(estado);
    });
    try {
      await ref.read(repositorioSocialProvider).decirSiVoy(antes.id, estado);
      // Decir que vas cuenta como noche, asi que mueve la racha, el
      // calendario y las salidas del perfil.
      refrescarPerfil(ref);
    } catch (e) {
      if (!mounted) return;
      setState(() => _l = antes);
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia ? e.mensaje : 'No se ha podido guardar. Prueba otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enCurso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tinta = BloquesPrevia.tintaSobreBloque;
    final yo = ref.watch(miPerfilProvider).valueOrNull;

    // Tu cara entra en la pila en cuanto dices que vas: es la confirmacion
    // mas clara de que te has apuntado, y la misma que veran los demas.
    final caras = [
      if (_l.voy && yo != null)
        Cara(id: yo.id, nombre: yo.nombre, avatar: yo.avatarUrl),
      ..._l.caras,
    ];
    final resto = (_l.van - caras.length).clamp(0, 999);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: 'Ver quién va a ${_l.nombre}',
          child: Pulsable(
            onTap: () => _verQuienVa(context, _l, widget.color),
            escala: 0.985,
            vibrar: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_l.zona != null && _l.zona!.isNotEmpty)
                        Flexible(
                          child: Text(
                            _l.zona!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tinta.withValues(alpha: .72),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      if (_l.aqui > 0) ...[
                        const SizedBox(width: EspaciadoPrevia.s),
                        _ChipDentro(cuantos: _l.aqui),
                      ],
                      // Hueco para el sticker del juego, que se pega encima.
                      if (_l.voy) const SizedBox(width: 120),
                    ],
                  ),
                  const SizedBox(height: EspaciadoPrevia.s),
                  Titular(_l.nombre, tamano: 40, color: tinta, lineas: 2),
                  const SizedBox(height: EspaciadoPrevia.m + 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (caras.isNotEmpty) ...[
                              AnimatedSwitcher(
                                duration: MovimientoPrevia.normal,
                                switchInCurve: MovimientoPrevia.curva,
                                child: PilaDeCaras(
                                  key: ValueKey(caras.length + resto),
                                  caras: caras,
                                  resto: caras.length >= 4 ? resto : 0,
                                  lado: 30,
                                  borde: widget.color,
                                ),
                              ),
                              const SizedBox(width: EspaciadoPrevia.s),
                            ],
                            Expanded(
                              child: Text(
                                _fraseSocial(_l, caras, yo?.id),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: tinta,
                                  fontSize: 13.5,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: EspaciadoPrevia.s),
                      SelectorVas(
                        estado: _l.miEstado,
                        nombreLocal: _l.nombre,
                        fondo: widget.color,
                        onElegir: _decir,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Como el sello de un cartel: pegado al borde, torcido, y solo en
        // los sitios a los que vas, porque el juego va de gente que esta en
        // el mismo local.
        if (_l.voy)
          Positioned(
            top: -12,
            right: 12,
            child: StickerNoHayHuevos(localId: _l.id)
                .animate()
                .fadeIn(duration: MovimientoPrevia.rapido)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: MovimientoPrevia.normal,
                ),
          ),
      ],
    );
  }
}

/// "Lucia, Dani y 12 mas": nombres antes que numeros, porque un nombre
/// conocido es lo que hace ir.
String _fraseSocial(Local l, List<Cara> caras, String? miId) {
  final otros = caras.where((c) => c.id != miId).toList();
  final restoOtros = l.van - (l.voy ? 1 : 0) - otros.length;
  final quiza = l.quiza > 0 ? ' · ${l.quiza} quizá' : '';

  if (l.van == 0) {
    return l.quiza > 0
        ? '${l.quiza} ${l.quiza == 1 ? 'se lo piensa' : 'se lo piensan'}. '
              'Decídelo tú.'
        : 'Nadie todavía. ¿Abres tú la noche?';
  }
  if (l.voy && l.van == 1) return 'De momento solo tú. Avisa a tu gente$quiza';

  if (otros.isEmpty) {
    final n = l.van - (l.voy ? 1 : 0);
    final base = n == 1 ? '1 persona va' : '$n personas van';
    return '${l.voy ? 'Tú y ' : ''}$base$quiza';
  }

  final nombres = otros.take(2).map((c) => c.nombre.split(' ').first).toList();
  final masOtros = restoOtros + (otros.length - nombres.length);
  final lista = masOtros > 0
      ? '${nombres.join(', ')} y $masOtros más'
      : nombres.join(' y ');
  final verbo = (masOtros > 0 || nombres.length > 1 || l.voy) ? 'van' : 'va';
  return '${l.voy ? 'Tú, ' : ''}$lista $verbo$quiza';
}

class _ChipDentro extends StatelessWidget {
  const _ChipDentro({required this.cuantos});

  final int cuantos;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: BloquesPrevia.tintaSobreBloque,
      borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF35E07F),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$cuantos DENTRO',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// Bloques con brillo con la forma de los carteles que van a llegar.
class _Esqueletos extends StatelessWidget {
  const _Esqueletos();

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    final reducido = MovimientoPrevia.reducido(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: EspaciadoPrevia.m),
      sliver: SliverList.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: EspaciadoPrevia.m),
        itemBuilder: (_, i) {
          final bloque = Container(
            height: 176,
            decoration: BoxDecoration(
              color: c.superficieAlta,
              borderRadius: BorderRadius.circular(28),
            ),
          );
          if (reducido) return bloque;
          return bloque
              .animate(onPlay: (a) => a.repeat())
              .shimmer(
                duration: 1400.ms,
                delay: (i * 120).ms,
                color: c.superficieActiva,
              );
        },
      ),
    );
  }
}

Future<void> _cambiarCiudad(
  BuildContext context,
  WidgetRef ref,
  String actual,
) async {
  final campo = TextEditingController(text: actual);
  final nueva = await mostrarHoja<String>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(contexto).bottom +
            MediaQuery.paddingOf(contexto).bottom +
            EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Titular('¿Dónde sales?', tamano: 28),
          const SizedBox(height: EspaciadoPrevia.m),
          TextField(
            controller: campo,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.place_outlined),
              hintText: 'Ciudad',
            ),
            onSubmitted: (v) => Navigator.of(contexto).pop(v),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(campo.text),
            child: const Text('VER ESTA NOCHE'),
          ),
        ],
      ),
    ),
  );
  campo.dispose();
  if (nueva != null) ref.read(ciudadDeLaNocheProvider.notifier).fijar(nueva);
}

Future<void> _proponerLocal(
  BuildContext context,
  WidgetRef ref,
  String ciudad,
) async {
  final nombre = TextEditingController();
  final instagram = TextEditingController();
  final mensajero = ScaffoldMessenger.of(context);

  final creado = await mostrarHoja<bool>(
    context,
    builder: (contexto) => Padding(
      padding: EdgeInsets.fromLTRB(
        EspaciadoPrevia.m,
        0,
        EspaciadoPrevia.m,
        MediaQuery.viewInsetsOf(contexto).bottom +
            MediaQuery.paddingOf(contexto).bottom +
            EspaciadoPrevia.m,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Titular('Un sitio nuevo en $ciudad', tamano: 26, lineas: 2),
          const SizedBox(height: EspaciadoPrevia.m),
          TextField(
            controller: nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre del sitio'),
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: instagram,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Instagram (opcional)',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: const Text('AÑADIR'),
          ),
        ],
      ),
    ),
  );

  final textoNombre = nombre.text.trim();
  final textoInstagram = instagram.text.trim().replaceAll('@', '');
  nombre.dispose();
  instagram.dispose();
  if (creado != true) return;
  if (textoNombre.length < 2) {
    mensajero.showSnackBar(
      const SnackBar(content: Text('El nombre necesita al menos 2 letras.')),
    );
    return;
  }

  try {
    await ref
        .read(repositorioSocialProvider)
        .crearLocal(
          nombre: textoNombre,
          ciudad: ciudad,
          instagram: textoInstagram.isEmpty ? null : textoInstagram,
        );
    ref.invalidate(localesProvider);
  } catch (_) {
    mensajero.showSnackBar(
      const SnackBar(content: Text('No se ha podido añadir el sitio.')),
    );
  }
}

Future<void> _abrir(String url) async {
  final destino = Uri.tryParse(url);
  if (destino == null) return;
  await launchUrl(destino, mode: LaunchMode.externalApplication);
}

/// Quien va a un local, agrupado por como va.
Future<void> _verQuienVa(BuildContext context, Local local, Color color) {
  return mostrarHoja<void>(
    context,
    arrastrable: true,
    altoInicial: 0.66,
    builder: (_) => _HojaQuienVa(local: local, color: color),
  );
}

class _HojaQuienVa extends ConsumerWidget {
  const _HojaQuienVa({required this.local, required this.color});

  final Local local;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colores;
    return FutureBuilder<List<Asistente>>(
      future: ref.read(repositorioSocialProvider).quienVa(local.id),
      builder: (context, resultado) {
        final gente = resultado.data ?? const <Asistente>[];

        return ListView(
          primary: true,
          padding: EdgeInsets.fromLTRB(
            EspaciadoPrevia.m,
            EspaciadoPrevia.m,
            EspaciadoPrevia.m,
            EspaciadoPrevia.l + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: EspaciadoPrevia.m),
                decoration: BoxDecoration(
                  color: c.superficieActiva,
                  borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
                ),
              ),
            ),
            Titular(local.nombre, tamano: 36, lineas: 2),
            if (local.zona != null) ...[
              const SizedBox(height: 4),
              Text(local.zona!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PantallaSala(
                          localId: local.id,
                          nombreLocal: local.nombre,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.forum_rounded, size: 19),
                  label: const Text('SALA'),
                ),
                if (local.tieneEntradas)
                  OutlinedButton.icon(
                    onPressed: () => _abrir(local.urlEntradas!),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    icon: const Icon(Icons.local_activity_rounded, size: 19),
                    label: const Text('ENTRADA'),
                  ),
                if (local.instagram != null && local.instagram!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _abrir('https://instagram.com/${local.instagram}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                    icon: const Icon(Icons.alternate_email_rounded, size: 19),
                    label: Text(local.instagram!),
                  ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.l),
            if (resultado.connectionState == ConnectionState.waiting)
              const Cargando()
            else if (resultado.hasError)
              const EstadoVacio(
                compacto: true,
                icono: Icons.cloud_off_rounded,
                titulo: 'Sin conexión',
                detalle: 'No hemos podido ver quién va.',
              )
            else if (gente.isEmpty)
              const EstadoVacio(
                compacto: true,
                pegatina: '👀',
                titulo: 'Nadie todavía',
                detalle: 'Di que vas y serás la primera cara de la lista.',
              )
            else
              for (final estado in EstadoNoche.values)
                ..._grupo(
                  context,
                  estado,
                  gente.where((g) => g.estado == estado).toList(),
                ),
          ],
        );
      },
    );
  }

  List<Widget> _grupo(
    BuildContext context,
    EstadoNoche estado,
    List<Asistente> gente,
  ) {
    if (gente.isEmpty) return const [];
    final titulo = switch (estado) {
      EstadoNoche.aqui => 'Ya están aquí',
      EstadoNoche.voy => 'Van',
      EstadoNoche.tarde => 'Van más tarde',
      EstadoNoche.quiza => 'Quizá',
    };
    return [
      Padding(
        padding: const EdgeInsets.only(
          top: EspaciadoPrevia.s,
          bottom: EspaciadoPrevia.xs,
        ),
        child: Row(
          children: [
            Text(estado.pegatina, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: EspaciadoPrevia.s),
            Titular(titulo, tamano: 18),
            const SizedBox(width: EspaciadoPrevia.s),
            Text(
              '${gente.length}',
              style: TextStyle(
                color: context.colores.textoTenue,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      for (final p in gente)
        ListTile(
          contentPadding: EdgeInsets.zero,
          minTileHeight: 60,
          onTap: () {
            Navigator.of(context).pop();
            context.push('${Rutas.perfilDe}/${p.id}');
          },
          leading: AvatarPerfil(
            url: p.avatar,
            inicial: p.nombre,
            lado: 46,
            anillo: estado == EstadoNoche.aqui
                ? context.colores.disponible
                : null,
          ),
          title: Text(p.nombre, style: Theme.of(context).textTheme.titleMedium),
          subtitle: p.usuario == null ? null : Text('@${p.usuario}'),
          trailing: p.leSigo
              ? Text(
                  'Le sigues',
                  style: TextStyle(
                    color: context.colores.textoTenue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(Icons.chevron_right, color: context.colores.textoTenue),
        ),
    ];
  }
}
