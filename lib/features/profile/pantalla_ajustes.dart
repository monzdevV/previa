import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/modo_de_tema.dart';
import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../core/entorno.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../../data/repositories/repositorio_retos.dart';
import '../juego/no_hay_huevos.dart' show nombreDelJuego;

/// Ajustes: todo lo que se usa de vez en cuando.
///
/// Aqui acaba lo que antes llenaba el perfil (solicitudes, valorar, datos,
/// borrar la cuenta). Agrupado como en los ajustes del movil: cuenta,
/// preferencias, privacidad y datos, y al final salir. Se encuentra porque
/// esta donde cualquiera lo buscaria, no porque este siempre a la vista.
class PantallaAjustes extends ConsumerStatefulWidget {
  const PantallaAjustes({super.key});

  @override
  ConsumerState<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends ConsumerState<PantallaAjustes> {
  /// Borrar la cuenta tarda y no se puede repetir: un segundo toque mientras
  /// va el primero lanzaria otra peticion contra una cuenta a medio borrar.
  bool _eliminando = false;

  @override
  Widget build(BuildContext context) {
    final moderador =
        ref.watch(miPerfilProvider).valueOrNull?.esModerador ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          EspaciadoPrevia.m,
          EspaciadoPrevia.s,
          EspaciadoPrevia.m,
          EspaciadoPrevia.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Grupo(
            titulo: 'Tu cuenta',
            filas: [
              _Fila(
                icono: Icons.edit_outlined,
                titulo: 'Editar perfil',
                detalle: 'Foto, usuario, redes y más',
                onTap: () => context.push(Rutas.editarPerfil),
              ),
              _Fila(
                icono: Icons.inbox_outlined,
                titulo: 'Mis solicitudes',
                detalle: 'Las plazas que has pedido',
                onTap: () => context.push(Rutas.misSolicitudes),
              ),
              _Fila(
                icono: Icons.star_outline_rounded,
                titulo: 'Previas a las que fui',
                detalle: 'Valora a la gente que conociste',
                onTap: () => context.push(Rutas.porValorar),
              ),
              if (moderador)
                _Fila(
                  icono: Icons.gavel_rounded,
                  titulo: 'Moderación',
                  detalle: 'Lo que ha reportado la gente',
                  onTap: () => context.push(Rutas.moderacion),
                ),
            ],
          ),
          const _Grupo(
            titulo: 'Preferencias',
            filas: [_ElectorDeTema(), _InterruptorDelJuego()],
          ),
          _Grupo(
            titulo: 'Privacidad',
            filas: [
              _Fila(
                icono: Icons.shield_outlined,
                titulo: 'Cómo cuidamos tu privacidad',
                detalle: 'Ubicación, direcciones y convivencia',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _ComoFunciona()),
                ),
              ),
              _Fila(
                icono: Icons.policy_outlined,
                titulo: 'Política de privacidad',
                onTap: () => context.push(Rutas.privacidad),
              ),
              _Fila(
                icono: Icons.description_outlined,
                titulo: 'Condiciones de uso',
                onTap: () => context.push(Rutas.condiciones),
              ),
            ],
          ),
          _Grupo(
            titulo: 'Tus datos',
            filas: [
              _Fila(
                icono: Icons.download_outlined,
                titulo: 'Descargar mis datos',
                detalle: 'Todo lo que guardamos de ti, en un fichero',
                onTap: _exportar,
              ),
              _Fila(
                icono: Icons.delete_outline,
                titulo: 'Eliminar mi cuenta',
                detalle: 'Se borra todo y no hay vuelta atrás',
                peligro: true,
                cargando: _eliminando,
                onTap: _eliminando ? null : _eliminarCuenta,
              ),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          OutlinedButton.icon(
            onPressed: () => ref.read(repositorioAuthProvider).salir(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: EspaciadoPrevia.l),
          Center(
            child: Text(
              'Previa · versión 1.0.0\n'
              'Trabajo de Fin de Grado · 2º DAM',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 12, color: context.colores.textoTenue),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportar() async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final datos = await ref.read(repositorioAuthProvider).exportarMisDatos();
      mensajero.showSnackBar(
        SnackBar(
          content: Text('Datos preparados: ${datos.keys.length} secciones.'),
        ),
      );
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se han podido exportar tus datos.')),
      );
    }
  }

  Future<void> _eliminarCuenta() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: context.colores.superficieAlta,
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borrarán tu perfil, tus previas, tus mensajes y tus '
          'valoraciones. Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colores.error,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || _eliminando || !mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    setState(() => _eliminando = true);
    try {
      await ref.read(repositorioAuthProvider).eliminarMiCuenta();
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text(
            'No se ha podido eliminar la cuenta. Inténtalo otra vez.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }
}

/// Un grupo de ajustes en su bloque redondeado, con su rotulo encima.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.filas});

  final String titulo;
  final List<Widget> filas;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: EspaciadoPrevia.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: EspaciadoPrevia.xs,
            bottom: EspaciadoPrevia.s,
          ),
          child: Titular(titulo, tamano: 18),
        ),
        Material(
          color: context.colores.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radioGrande),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < filas.length; i++) ...[
                if (i > 0) const Divider(indent: 56, height: 1),
                filas[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.detalle,
    this.peligro = false,
    this.cargando = false,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback? onTap;
  final bool peligro;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final c = context.colores;
    return ListTile(
      minTileHeight: 56,
      leading: Icon(icono, color: peligro ? c.error : c.textoSuave),
      title: Text(
        titulo,
        style: TextStyle(
          color: peligro ? c.error : c.texto,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: detalle == null ? null : Text(detalle!),
      trailing: cargando
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: c.error),
            )
          : Icon(Icons.chevron_right, color: c.textoTenue),
      onTap: onTap,
    );
  }
}

/// Como se trata tu ubicacion y tus datos, contado como se habla.
///
/// El RGPD exige que la información sea inteligible y en lenguaje claro
/// (art. 12). Por eso está redactado como se habla, no como un contrato:
/// una política que nadie entiende no informa a nadie. Antes ocupaba la
/// pantalla de ajustes entera y tapaba los ajustes de verdad.
class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu privacidad')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          EspaciadoPrevia.l,
          EspaciadoPrevia.s,
          EspaciadoPrevia.l,
          EspaciadoPrevia.l + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _Apartado(
            titulo: 'Tu ubicación',
            icono: Icons.place_outlined,
            parrafos: [
              'Usamos tu ubicación para una sola cosa: enseñarte previas que '
                  'tengas cerca. No la guardamos en ningún sitio. Se usa para '
                  'hacer la búsqueda y se descarta.',
              'Pedimos únicamente precisión aproximada, no la exacta. Para un '
                  'radio de kilómetros sobra, y así gastamos menos batería.',
              'Si no nos das permiso, la app sigue funcionando: puedes mover '
                  'el mapa a mano y buscar por zona.',
            ],
          ),

          _Apartado(
            titulo: 'La dirección de las previas',
            icono: Icons.lock_outline,
            parrafos: [
              'Cuando publicas una previa, tu dirección exacta no la ve nadie. '
                  'En el mapa apareces dentro de un círculo de unos '
                  '${Entorno.metrosDeDifuminado} metros, desplazado al azar.',
              'Solo cuando aceptas a alguien, esa persona puede ver el punto '
                  'exacto. Y esa regla no vive en la app: vive en la base de '
                  'datos, donde no se puede saltar.',
              'El desplazamiento se calcula una sola vez y se queda fijo. Si '
                  'cambiara en cada consulta, alguien podría deducir el centro '
                  'real mirando varias veces.',
            ],
          ),

          _Apartado(
            titulo: 'Qué datos guardamos',
            icono: Icons.inventory_2_outlined,
            parrafos: [
              'Lo mínimo: tu nombre, un nombre de usuario, tu correo y tu fecha '
                  'de nacimiento. No pedimos teléfono, ni apellidos, ni '
                  'dirección postal.',
              'Tu fecha de nacimiento no la ve nadie, ni siquiera se envía a la '
                  'app de otras personas. Solo se publica tu edad en años.',
              'Las previas caducan: se cierran unas horas después de empezar y '
                  'se borran a las 48 horas. Lo único que permanece es tu '
                  'perfil y tu reputación.',
            ],
          ),

          _Apartado(
            titulo: 'Tus derechos',
            icono: Icons.gavel_outlined,
            parrafos: [
              'Puedes descargar todo lo que tenemos sobre ti desde tu perfil, '
                  'en un fichero que puedes llevarte a otro sitio.',
              'Puedes eliminar tu cuenta cuando quieras. Se borra todo: perfil, '
                  'previas, mensajes y valoraciones. No hay copia oculta.',
              'Si algo no te cuadra, puedes reclamar ante la Agencia Española '
                  'de Protección de Datos.',
            ],
          ),

          _Apartado(
            titulo: 'Solo mayores de 18',
            icono: Icons.verified_user_outlined,
            parrafos: [
              'Previa es para mayores de edad. Al registrarte se comprueba tu '
                  'fecha de nacimiento y los menores no pueden entrar.',
              'Si sospechas que alguien es menor, repórtalo: hay un motivo '
                  'específico para eso.',
            ],
          ),

          _Apartado(
            titulo: 'Convivencia',
            icono: Icons.handshake_outlined,
            parrafos: [
              'Nadie entra en una previa sin que el anfitrión lo acepte.',
              'Si bloqueas a alguien, desaparece del todo: no veis vuestras '
                  'previas, no puede pedirte plaza y no puede escribirte.',
              'Puedes reportar perfiles, previas y mensajes. Los reportes se '
                  'revisan.',
              'Previa no puede garantizar lo que pase en un encuentro '
                  'presencial. Usa la cabeza: queda con gente con reputación, '
                  'avisa a alguien de dónde vas y vete si algo no te gusta.',
            ],
          ),

        ],
      ),
    );
  }
}

class _Apartado extends StatelessWidget {
  const _Apartado({
    required this.titulo,
    required this.icono,
    required this.parrafos,
  });

  final String titulo;
  final IconData icono;
  final List<String> parrafos;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: EspaciadoPrevia.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: context.colores.primarioSuave),
              const SizedBox(width: EspaciadoPrevia.s),
              Expanded(child: Text(titulo, style: textos.titleLarge)),
            ],
          ),
          const SizedBox(height: EspaciadoPrevia.s),
          for (final p in parrafos)
            Padding(
              padding: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
              child: Text(p, style: textos.bodyMedium?.copyWith(height: 1.5)),
            ),
        ],
      ),
    );
  }
}

/// Claro, oscuro o el del sistema.
class _ElectorDeTema extends ConsumerWidget {
  const _ElectorDeTema();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoDeTemaProvider);

    return Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aspecto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: EspaciadoPrevia.s),
          SegmentedButton<ThemeMode>(
            segments: [
              for (final m in ThemeMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.enEspanol),
                  icon: Icon(m.icono, size: 18),
                ),
            ],
            selected: {modo},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(modoDeTemaProvider.notifier).fijar(s.first),
          ),
        ],
      ),
    );
  }
}

/// Salir o no en los retos de los demas. Esta en ajustes y no escondido en
/// el juego porque es una decision sobre ti, no sobre una partida.
class _InterruptorDelJuego extends ConsumerStatefulWidget {
  const _InterruptorDelJuego();

  @override
  ConsumerState<_InterruptorDelJuego> createState() =>
      _InterruptorDelJuegoState();
}

class _InterruptorDelJuegoState extends ConsumerState<_InterruptorDelJuego> {
  bool? _juego;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    ref.read(repositorioRetosProvider).juego().then(
      (valor) {
        if (mounted) setState(() => _juego = valor);
      },
      onError: (_) {
        if (mounted) setState(() => _juego = true);
      },
    );
  }

  Future<void> _cambiar(bool valor) async {
    if (_guardando) return;
    final antes = _juego;
    setState(() {
      _juego = valor;
      _guardando = true;
    });
    try {
      await ref.read(repositorioRetosProvider).cambiarJuego(juego: valor);
    } catch (_) {
      if (!mounted) return;
      setState(() => _juego = antes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se ha podido guardar.')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: const Icon(Icons.egg_outlined),
    title: Text('Salir en retos de $nombreDelJuego'),
    subtitle: const Text(
      'Si lo apagas, a nadie le tocará buscarte en un local.',
    ),
    value: _juego ?? true,
    onChanged: _juego == null || _guardando ? null : _cambiar,
  );
}
