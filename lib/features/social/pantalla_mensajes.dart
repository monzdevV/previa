import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/rutas.dart';
import '../../app/tema.dart';
import '../../data/models/publicacion.dart';
import '../../data/repositories/repositorio_social.dart';

final conversacionesProvider = FutureProvider<List<Conversacion>>(
  (ref) => ref.watch(repositorioSocialProvider).misConversaciones(),
);

// Se cierra al salir de la conversacion: si no, cada chat abierto dejaria su
// suscripcion de Realtime viva hasta cerrar la aplicacion.
final _mensajesProvider = StreamProvider.autoDispose
    .family<List<MensajeDirecto>, String>(
      (ref, otroId) =>
          ref.watch(repositorioSocialProvider).flujoDeMensajes(otroId),
    );

/// La bandeja de mensajes, como pantalla suelta. Se llega aqui desde un
/// aviso; lo normal es verla dentro del buzon.
class PantallaMensajes extends StatelessWidget {
  const PantallaMensajes({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mensajes')),
    body: const ListaConversaciones(),
  );
}

/// Las conversaciones, sin marco: la usan el buzon y la pantalla suelta.
class ListaConversaciones extends ConsumerWidget {
  const ListaConversaciones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversaciones = ref.watch(conversacionesProvider);

    return conversaciones.when(
      loading: () => const Cargando(),
      error: (e, _) => EstadoVacio(
        icono: Icons.cloud_off_rounded,
        titulo: 'Sin conexión',
        detalle: 'No hemos podido traer tus mensajes.',
        accion: 'Reintentar',
        onAccion: () => ref.invalidate(conversacionesProvider),
      ),
      data: (lista) => lista.isEmpty
          ? EstadoVacio(
              pegatina: '💬',
              titulo: 'Aún no hablas con nadie',
              detalle:
                  'Puedes escribir a quien sigues o a quien te sigue. '
                  'Busca a tu gente y empieza.',
              accion: 'Buscar gente',
              onAccion: () => context.push(Rutas.buscar),
            )
          : RefreshIndicator(
              color: context.colores.primarioTexto,
              backgroundColor: context.colores.superficie,
              onRefresh: () async => ref.refresh(conversacionesProvider.future),
              child: ListView.builder(
                itemCount: lista.length,
                itemBuilder: (_, i) => _Fila(conversacion: lista[i]),
              ),
            ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.conversacion});

  final Conversacion conversacion;

  @override
  Widget build(BuildContext context) {
    final c = conversacion;
    final textos = Theme.of(context).textTheme;
    final sinLeer = c.sinLeer > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: EspaciadoPrevia.m,
        vertical: EspaciadoPrevia.xs,
      ),
      leading: AvatarPerfil(url: c.avatar, inicial: c.nombre, lado: 52),
      title: Text(c.nombre, style: textos.titleMedium),
      subtitle: Text(
        c.ultimo == null
            ? ''
            : c.ultimoMio
            ? 'Tú: ${c.ultimo}'
            : c.ultimo!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textos.bodyMedium?.copyWith(
          color: sinLeer ? context.colores.texto : context.colores.textoTenue,
          fontWeight: sinLeer ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _cuando(c.ultimoEn),
            style: textos.labelMedium?.copyWith(
              color: context.colores.textoTenue,
            ),
          ),
          if (sinLeer) ...[
            const SizedBox(height: EspaciadoPrevia.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: context.colores.primario,
                borderRadius: BorderRadius.circular(EspaciadoPrevia.pastilla),
              ),
              child: Text(
                '${c.sinLeer}',
                style: TextStyle(
                  color: context.colores.sobrePrimario,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('${Rutas.conversacion}/${c.otroId}'),
    );
  }
}

/// Una conversacion con alguien.
class PantallaConversacion extends ConsumerStatefulWidget {
  const PantallaConversacion({super.key, required this.otroId});

  final String otroId;

  @override
  ConsumerState<PantallaConversacion> createState() =>
      _PantallaConversacionState();
}

class _PantallaConversacionState extends ConsumerState<PantallaConversacion> {
  final _campo = TextEditingController();
  bool _enviando = false;

  /// En `dispose` ya no se puede usar `ref`, asi que el contenedor se guarda
  /// al entrar para poder refrescar la bandeja al salir.
  late final ProviderContainer _contenedor;

  @override
  void initState() {
    super.initState();
    _contenedor = ProviderScope.containerOf(context, listen: false);
    // Al abrir se marcan como leidos: si esperase a cerrar, el contador
    // seguiria en rojo mientras lees.
    ref.read(repositorioSocialProvider).marcarLeidos(widget.otroId);
  }

  @override
  void dispose() {
    _campo.dispose();
    // La bandeja se refresca al volver para que el contador de no leidos y
    // el ultimo mensaje reflejen lo que acaba de pasar aqui. Va en una
    // microtarea porque invalidar mientras se desmonta el arbol esta vetado.
    final contenedor = _contenedor;
    Future.microtask(() => contenedor.invalidate(conversacionesProvider));
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _campo.text;
    if (texto.trim().isEmpty || _enviando) return;

    setState(() => _enviando = true);
    _campo.clear();
    try {
      await ref
          .read(repositorioSocialProvider)
          .enviarMensaje(widget.otroId, texto);
      ref.invalidate(conversacionesProvider);
    } catch (e) {
      if (mounted) {
        _campo.text = texto;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se ha podido enviar. Solo puedes escribir a quien sigues '
              'o te sigue.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mensajes = ref.watch(_mensajesProvider(widget.otroId));
    // La bandeja ya trae nombre y cara de la otra persona; se aprovecha si
    // esta cargada en vez de pedir su perfil solo para la cabecera.
    final otro = ref
        .watch(conversacionesProvider)
        .valueOrNull
        ?.where((c) => c.otroId == widget.otroId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: otro == null
            ? const Text('Conversación')
            : Row(
                children: [
                  AvatarPerfil(url: otro.avatar, inicial: otro.nombre, lado: 34),
                  const SizedBox(width: EspaciadoPrevia.s + EspaciadoPrevia.xs),
                  Expanded(
                    child: Text(otro.nombre, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Ver perfil',
            onPressed: () =>
                context.push('${Rutas.perfilDe}/${widget.otroId}'),
          ),
          const SizedBox(width: EspaciadoPrevia.s),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: mensajes.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: context.colores.primarioTexto,
                ),
              ),
              error: (e, _) =>
                  const _Mensaje(texto: 'No se ha podido cargar el chat.'),
              data: (lista) => lista.isEmpty
                  ? const _Mensaje(texto: 'Aún no os habéis escrito.')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(EspaciadoPrevia.m),
                      itemCount: lista.length,
                      // Se pinta al reves para que lo nuevo quede abajo sin
                      // tener que mover el scroll a mano en cada mensaje.
                      itemBuilder: (_, i) =>
                          _Burbuja(mensaje: lista[lista.length - 1 - i]),
                    ),
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                EspaciadoPrevia.m,
                EspaciadoPrevia.s,
                EspaciadoPrevia.m,
                EspaciadoPrevia.s,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _campo,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Escribe algo',
                      ),
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(width: EspaciadoPrevia.s),
                  IconButton.filled(
                    onPressed: _enviando ? null : _enviar,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: context.colores.primario,
                      foregroundColor: context.colores.sobrePrimario,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje});

  final MensajeDirecto mensaje;

  @override
  Widget build(BuildContext context) {
    final mio = mensaje.mio;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: EspaciadoPrevia.s),
        padding: const EdgeInsets.symmetric(
          horizontal: EspaciadoPrevia.m,
          vertical: EspaciadoPrevia.s + EspaciadoPrevia.xs,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mio ? context.colores.primario : context.colores.superficieAlta,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(EspaciadoPrevia.radio),
            topRight: const Radius.circular(EspaciadoPrevia.radio),
            bottomLeft: Radius.circular(mio ? EspaciadoPrevia.radio : 4),
            bottomRight: Radius.circular(mio ? 4 : EspaciadoPrevia.radio),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              mensaje.texto,
              style: TextStyle(
                color: mio ? context.colores.sobrePrimario : context.colores.texto,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('HH:mm').format(mensaje.enviadoEn),
              style: TextStyle(
                fontSize: 10,
                color: mio
                    ? context.colores.sobrePrimario.withValues(alpha: 0.6)
                    : context.colores.textoTenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cuando(DateTime momento) {
  final d = DateTime.now().difference(momento);
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  if (d.inHours < 24) return '${d.inHours} h';
  if (d.inDays < 7) return '${d.inDays} d';
  return DateFormat('d MMM', 'es_ES').format(momento);
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(EspaciadoPrevia.xl),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
