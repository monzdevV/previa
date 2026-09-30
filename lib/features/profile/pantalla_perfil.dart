import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/perfil.dart';
import '../../data/repositories/repositorio_auth.dart';
import '../map/proveedores_mapa.dart';
import '../party/tarjeta_previa.dart';
import '../safety/exportar_datos.dart';
import 'avatar_previa.dart';
import 'reputacion.dart';

class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(miPerfilProvider);
    final misPrevias = ref.watch(misPreviasProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Rutas.editarPerfil),
          ),
          // Ajustes a un toque desde la cabecera: antes solo se llegaba por
          // una fila llamada "Privacidad y convivencia" que no se asociaba.
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Rutas.ajustes),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(miPerfilProvider);
          ref.invalidate(misPreviasProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(EspaciadoPrevia.l),
          children: [
            perfil.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(EspaciadoPrevia.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'No se ha podido cargar tu perfil.',
                style: textos.bodyMedium,
              ),
              data: (p) => _CabeceraPerfil(perfil: p),
            ),

            const SizedBox(height: EspaciadoPrevia.xl),
            Row(
              children: [
                Expanded(child: Text('Mis previas', style: textos.titleLarge)),
                TextButton.icon(
                  onPressed: () => context.push(Rutas.crearPrevia),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Abrir'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ],
            ),
            const SizedBox(height: EspaciadoPrevia.s),

            misPrevias.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(EspaciadoPrevia.l),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'No se han podido cargar tus previas.',
                style: textos.bodyMedium,
              ),
              data: (lista) => lista.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(EspaciadoPrevia.l),
                      decoration: BoxDecoration(
                        color: ColoresPrevia.superficie,
                        borderRadius: BorderRadius.circular(
                          EspaciadoPrevia.radio,
                        ),
                        border: Border.all(color: ColoresPrevia.borde),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.nightlife_outlined,
                            size: 32,
                            color: ColoresPrevia.textoTenue,
                          ),
                          const SizedBox(height: EspaciadoPrevia.s),
                          Text(
                            'Todavía no has abierto ninguna previa.',
                            style: textos.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (final p in lista)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: EspaciadoPrevia.s,
                            ),
                            child: TarjetaPrevia(
                              previa: p,
                              compacta: true,
                              onTap: () =>
                                  context.push('${Rutas.previa}/${p.id}'),
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: EspaciadoPrevia.l),
            _FilaAcceso(
              icono: Icons.waving_hand_outlined,
              titulo: 'Mis solicitudes',
              detalle: 'Las plazas que has pedido',
              onTap: () => context.push(Rutas.misSolicitudes),
            ),
            _FilaAcceso(
              icono: Icons.star_outline_rounded,
              titulo: 'Previas a las que fui',
              detalle: 'Valora a la gente que conociste',
              onTap: () => context.push(Rutas.porValorar),
            ),
            _FilaAcceso(
              icono: Icons.settings_outlined,
              titulo: 'Ajustes',
              detalle: 'Privacidad, convivencia y bloqueos',
              onTap: () => context.push(Rutas.ajustes),
            ),

            const SizedBox(height: EspaciadoPrevia.m),
            const Divider(),
            const SizedBox(height: EspaciadoPrevia.m),

            Text('Tus datos', style: textos.titleLarge),
            const SizedBox(height: EspaciadoPrevia.s),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: const Text('Descargar mis datos'),
              subtitle: const Text(
                'Todo lo que guardamos de ti, en un fichero',
              ),
              onTap: () => _exportar(context, ref),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.delete_outline,
                color: ColoresPrevia.error,
              ),
              title: const Text(
                'Eliminar mi cuenta',
                style: TextStyle(color: ColoresPrevia.error),
              ),
              subtitle: const Text('Se borra todo y no hay vuelta atrás'),
              onTap: () => _eliminarCuenta(context, ref),
            ),

            const SizedBox(height: EspaciadoPrevia.l),
            OutlinedButton.icon(
              onPressed: () => ref.read(repositorioAuthProvider).salir(),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
            const SizedBox(height: EspaciadoPrevia.l),
          ],
        ),
      ),
    );
  }

  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final datos = await ref.read(repositorioAuthProvider).exportarMisDatos();
      final entregado = await entregarExportacion(datos);
      if (entregado) {
        mensajero.showSnackBar(
          const SnackBar(content: Text('Fichero con tus datos listo.')),
        );
      }
    } catch (e) {
      // ErrorPrevia trae mensaje propio; cualquier otro fallo (p. ej. no
      // hay hoja de compartir) recibe un texto generico.
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia
                ? e.mensaje
                : 'No se ha podido guardar el fichero con tus datos.',
          ),
        ),
      );
    }
  }

  Future<void> _eliminarCuenta(BuildContext context, WidgetRef ref) async {
    final mensajero = ScaffoldMessenger.of(context);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogoEliminarCuenta(),
    );

    if (confirmado != true) return;
    try {
      await ref.read(repositorioAuthProvider).eliminarMiCuenta();
    } catch (e) {
      // Antes el fallo se perdia en silencio y el usuario creia que se
      // habia borrado o que la app estaba colgada.
      mensajero.showSnackBar(
        SnackBar(
          content: Text(
            e is ErrorPrevia
                ? e.mensaje
                : 'No se ha podido eliminar la cuenta.',
          ),
        ),
      );
    }
  }
}

/// Pide escribir ELIMINAR: un toque accidental no debe borrar una cuenta.
class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta();

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _texto.text.trim().toUpperCase() == 'ELIMINAR';
    return AlertDialog(
      backgroundColor: ColoresPrevia.superficieAlta,
      title: const Text('¿Eliminar tu cuenta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se borrarán tu perfil, tus previas, tus mensajes y tus '
            'valoraciones. Esto no se puede deshacer.',
          ),
          const SizedBox(height: EspaciadoPrevia.m),
          const Text('Escribe ELIMINAR para confirmar:'),
          const SizedBox(height: EspaciadoPrevia.s),
          TextField(
            controller: _texto,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: listo ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresPrevia.error,
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}

/// Avatar grande con anillo, nombre, reputacion e insignias.
class _CabeceraPerfil extends StatelessWidget {
  const _CabeceraPerfil({required this.perfil});

  final Perfil? perfil;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final p = perfil;
    final sinMovimiento = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        // El anillo es un degradado de marca con un hueco del color del
        // fondo: destaca la foto sin depender de que la haya.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: sinMovimiento ? 1 : 0.85, end: 1),
          duration: sinMovimiento
              ? Duration.zero
              : const Duration(milliseconds: 450),
          curve: Curves.easeOutBack,
          builder: (_, escala, hijo) =>
              Transform.scale(scale: escala, child: hijo),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ColoresPrevia.primario, ColoresPrevia.acento],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ColoresPrevia.fondo,
              ),
              child: AvatarPrevia(
                iniciales: p?.iniciales ?? '?',
                url: p?.avatarUrl,
                radio: 52,
                etiqueta: 'Tu foto de perfil',
              ),
            ),
          ),
        ),
        const SizedBox(height: EspaciadoPrevia.m),
        Text(
          p?.nombre ?? '',
          style: textos.headlineMedium,
          textAlign: TextAlign.center,
        ),
        Text('@${p?.username ?? ''}', style: textos.bodyMedium),
        if (p != null && (p.bio ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: EspaciadoPrevia.s),
          Text(
            p.bio!.trim(),
            style: textos.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        if (p != null) ...[
          const SizedBox(height: EspaciadoPrevia.m),
          _TarjetaReputacion(perfil: p),
        ],
      ],
    );
  }
}

class _TarjetaReputacion extends StatelessWidget {
  const _TarjetaReputacion({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final tiene = perfil.tieneReputacion;
    final n = perfil.numeroValoraciones;
    final resumen = tiene
        ? 'Reputación ${perfil.reputacion!.toStringAsFixed(1)} sobre 5, '
              '$n ${n == 1 ? 'valoración' : 'valoraciones'}'
        : 'Aún sin valoraciones';

    return Semantics(
      container: true,
      label: resumen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(EspaciadoPrevia.m),
        decoration: BoxDecoration(
          color: ColoresPrevia.superficie,
          borderRadius: BorderRadius.circular(EspaciadoPrevia.radio),
          border: Border.all(color: ColoresPrevia.borde),
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: tiene
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ContadorAnimado(
                          valor: perfil.reputacion!,
                          decimales: 1,
                          estilo: textos.displaySmall,
                        ),
                        const SizedBox(width: EspaciadoPrevia.s),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('/ 5', style: textos.bodyMedium),
                        ),
                      ],
                    )
                  : Text('Sin valorar', style: textos.titleLarge),
            ),
            const SizedBox(height: EspaciadoPrevia.xs),
            EstrellasMedia(media: perfil.reputacion ?? 0, tamano: 24),
            const SizedBox(height: EspaciadoPrevia.xs),
            ExcludeSemantics(
              child: tiene
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ContadorAnimado(
                          valor: n.toDouble(),
                          estilo: textos.bodyMedium,
                        ),
                        Text(
                          n == 1 ? ' valoración' : ' valoraciones',
                          style: textos.bodyMedium,
                        ),
                      ],
                    )
                  : Text(
                      'Las recibirás al terminar tus previas',
                      style: textos.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: EspaciadoPrevia.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: EspaciadoPrevia.s,
              runSpacing: EspaciadoPrevia.s,
              children: [
                for (final i in insigniasDe(perfil))
                  Tooltip(
                    message: i.descripcion,
                    child: Semantics(
                      label: '${i.texto}. ${i.descripcion}',
                      excludeSemantics: true,
                      child: Chip(
                        avatar: Icon(
                          i.icono,
                          size: 18,
                          color: ColoresPrevia.primarioSuave,
                        ),
                        label: Text(i.texto),
                        backgroundColor: ColoresPrevia.superficieAlta,
                        side: BorderSide.none,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de acceso con objetivo tactil de al menos 48 dp.
class _FilaAcceso extends StatelessWidget {
  const _FilaAcceso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      leading: Icon(icono),
      title: Text(titulo),
      subtitle: Text(detalle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
